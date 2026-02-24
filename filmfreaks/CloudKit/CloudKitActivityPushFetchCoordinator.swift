//
//  CloudKitActivityPushFetchCoordinator.swift
//  filmfreaks
//
//  P2 (full): Fetch the changed record for an incoming CloudKit push,
//  decode a minimal activity summary, and show a local notification
//  (deduped + best-effort own-action suppression).
//

import Foundation
import CloudKit

enum CloudKitActivityPushFetchCoordinator {

    private static let container = CKContainer.default()

    /// P2 (full): Primary entry point used by AppDelegate.
    ///
    /// Returns true if we fetched a record (even if we decide to skip notifying).
    static func fetchAndHandle(userInfo: [AnyHashable: Any]) async -> Bool {
        #if DEBUG
        guard let ck = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return false
        }

        guard ck.notificationType == .query, let q = ck as? CKQueryNotification else {
            // For now we only handle query subscriptions.
            return false
        }

        guard
            let subscriptionID = q.subscriptionID,
            let parsed = CloudKitActivitySubscriptionID.parse(subscriptionID)
        else {
            return false
        }

        guard let ctx = GroupContextStore.context(forGroupId: parsed.groupId) else {
            print("[Push] Fetch skipped: no GroupContext for groupId=\(parsed.groupId)")
            return false
        }

        guard let recordID = normalizedRecordID(from: q.recordID, groupContext: ctx) else {
            print("[Push] Fetch skipped: missing recordID")
            return false
        }

        let db: CKDatabase = ctx.isShared ? container.sharedCloudDatabase : container.privateCloudDatabase

        do {
            let record = try await fetchRecord(database: db, recordID: recordID)

            let summary = decodeSummary(kind: parsed.kind, record: record, groupContext: ctx)
            logFetchResult(kind: parsed.kind, record: record, summary: summary, groupId: ctx.id)

            if let summary {
                await GroupActivityLocalNotifier.shared.maybeNotify(summary)
            }

            return true
        } catch {
            print("[Push] Fetch failed kind=\(parsed.kind.rawValue) groupId=\(ctx.id) recordID=\(recordID.recordName) error=\(error)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Backward-compatible alias.
    /// Your earlier P2 light called this method name.
    static func fetchAndLog(userInfo: [AnyHashable: Any]) async -> Bool {
        await fetchAndHandle(userInfo: userInfo)
    }

    // MARK: - Fetch

    private static func fetchRecord(database: CKDatabase, recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { cont in
            database.fetch(withRecordID: recordID) { record, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                if let record {
                    cont.resume(returning: record)
                    return
                }
                cont.resume(throwing: NSError(
                    domain: "CloudKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing CKRecord"]
                ))
            }
        }
    }

    private static func normalizedRecordID(from incoming: CKRecord.ID?, groupContext ctx: GroupContext) -> CKRecord.ID? {
        guard let incoming else { return nil }

        // `CKRecord.ID.zoneID` is non-optional, but it can still point at a different zone
        // (e.g. default zone). Ensure we fetch from the zone that belongs to the GroupContext.
        let expectedZoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
        let incomingZoneID = incoming.zoneID

        if incomingZoneID.zoneName == expectedZoneID.zoneName,
           incomingZoneID.ownerName == expectedZoneID.ownerName {
            return incoming
        }

        return CKRecord.ID(recordName: incoming.recordName, zoneID: expectedZoneID)
    }

    // MARK: - Decode

    private static func decodeSummary(
        kind: CloudKitActivitySubscriptionID.Kind,
        record: CKRecord,
        groupContext ctx: GroupContext
    ) -> GroupActivityNotificationSummary? {
        switch kind {
        case .movie:
            return decodeMovieSummary(record: record, groupContext: ctx)
        case .rating:
            return decodeRatingSummary(record: record, groupContext: ctx)
        case .movieNightActivity:
            return decodeMovieNightActivitySummary(record: record, groupContext: ctx)
        }
    }

    private static func decodeMovieSummary(record: CKRecord, groupContext ctx: GroupContext) -> GroupActivityNotificationSummary? {
        guard let data = record["payload"] as? Data else { return nil }
        guard let movie = try? JSONDecoder().decode(Movie.self, from: data) else { return nil }

        let groupId = (record["groupId"] as? String) ?? movie.groupId ?? ctx.id
        let actorName = movie.addedByName
        let actorId = movie.addedById

        let title = "In \(ctx.name)"
        let bodyActor = (actorName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? actorName! : "Jemand"
        let body = "\(bodyActor) hat „\(movie.title)“ hinzugefügt."

        return GroupActivityNotificationSummary(
            kind: .movie,
            groupId: groupId,
            groupName: ctx.name,
            recordID: record.recordID.recordName,
            actorName: actorName,
            actorId: actorId,
            title: title,
            body: body,
            userInfo: [
                "groupId": groupId,
                "kind": "movie",
                "movieId": movie.id.uuidString,
                "recordID": record.recordID.recordName
            ]
        )
    }

    private static func decodeRatingSummary(record: CKRecord, groupContext ctx: GroupContext) -> GroupActivityNotificationSummary? {
        guard let data = record["payload"] as? Data else { return nil }
        guard let rating = try? JSONDecoder().decode(Rating.self, from: data) else { return nil }

        let groupId = (record["groupId"] as? String) ?? ctx.id
        let movieId = (record["movieId"] as? String) ?? ""

        let actorName = rating.reviewerName
        let actorId = rating.reviewerId

        let score10: String = {
            if let f = rating.fazitScore { return String(f) }
            let approx = Int((rating.averageScoreNormalizedTo10).rounded())
            return String(approx)
        }()

        let title = "Neue Bewertung"
        let body = "\(actorName) hat eine Bewertung abgegeben (\(score10)/10)."

        return GroupActivityNotificationSummary(
            kind: .rating,
            groupId: groupId,
            groupName: ctx.name,
            recordID: record.recordID.recordName,
            actorName: actorName,
            actorId: actorId,
            title: title,
            body: body,
            userInfo: [
                "groupId": groupId,
                "kind": "rating",
                "movieId": movieId,
                "reviewerId": actorId?.uuidString ?? "",
                "recordID": record.recordID.recordName
            ]
        )
    }

    private static func decodeMovieNightActivitySummary(record: CKRecord, groupContext ctx: GroupContext) -> GroupActivityNotificationSummary? {
        let groupId = (record["groupId"] as? String) ?? ctx.id

        guard
            let kindRaw = record["kind"] as? String,
            let actorName = record["actorName"] as? String
        else { return nil }

        let eventId = (record["eventId"] as? String) ?? ""
        let decision = record["decision"] as? String
        let newStatus = record["newStatus"] as? String

        let title = "Filmabend-Update"
        let body: String = {
            if let decision, !decision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(actorName) hat reagiert: \(decision)."
            }
            if let newStatus, !newStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(actorName) hat den Status geändert: \(newStatus)."
            }
            return "\(actorName) hat den Filmabend aktualisiert."
        }()

        return GroupActivityNotificationSummary(
            kind: .movieNightActivity,
            groupId: groupId,
            groupName: ctx.name,
            recordID: record.recordID.recordName,
            actorName: actorName,
            actorId: nil,
            title: title,
            body: body,
            userInfo: [
                "groupId": groupId,
                "kind": "movieNightActivity",
                "eventId": eventId,
                "activityKind": kindRaw,
                "recordID": record.recordID.recordName
            ]
        )
    }

    // MARK: - Debug

    private static func logFetchResult(
        kind: CloudKitActivitySubscriptionID.Kind,
        record: CKRecord,
        summary: GroupActivityNotificationSummary?,
        groupId: String
    ) {
        if let summary {
            print("[Push] ✅ fetched \(kind.rawValue) groupId=\(summary.groupId) recordID=\(summary.recordID) actor=\(summary.actorName ?? "(nil)")")
        } else {
            print("[Push] ✅ fetched \(kind.rawValue) groupId=\(groupId) recordID=\(record.recordID.recordName) (no summary decode)")
        }
    }
}
