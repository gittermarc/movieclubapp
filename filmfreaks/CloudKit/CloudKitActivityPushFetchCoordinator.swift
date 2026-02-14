//
//  CloudKitActivityPushFetchCoordinator.swift
//  filmfreaks
//
//  P2 (light): Fetch the changed record for an incoming CloudKit push and log
//  a short summary.
//
//  This intentionally does NOT create user-facing notifications yet.
//  It is purely an end-to-end verification step:
//  push -> subscriptionID -> group routing (private/shared + zone) -> record fetch
//  -> minimal decode -> log.
//

import Foundation
import CloudKit

enum CloudKitActivityPushFetchCoordinator {

    private static let container = CKContainer.default()

    /// Returns true if we fetched a record and produced a summary log.
    static func fetchAndLog(userInfo: [AnyHashable: Any]) async -> Bool {
        #if DEBUG
        guard let ck = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return false
        }

        guard ck.notificationType == .query, let q = ck as? CKQueryNotification else {
            // For P2 (light) we only handle query subscriptions.
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
            logSummary(kind: parsed.kind, record: record, fallbackGroupId: ctx.id)
            return true
        } catch {
            print("[Push] Fetch failed kind=\(parsed.kind.rawValue) groupId=\(ctx.id) recordID=\(recordID.recordName) error=\(error)")
            return false
        }
        #else
        return false
        #endif
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
                cont.resume(throwing: NSError(domain: "CloudKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing CKRecord"]))
            }
        }
    }

    private static func normalizedRecordID(from incoming: CKRecord.ID?, groupContext ctx: GroupContext) -> CKRecord.ID? {
        guard let incoming else { return nil }
        // Most of the time CloudKit provides zoneID already.
        if incoming.zoneID != nil { return incoming }

        let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
        return CKRecord.ID(recordName: incoming.recordName, zoneID: zoneID)
    }

    // MARK: - Decode + Log

    private static func logSummary(kind: CloudKitActivitySubscriptionID.Kind, record: CKRecord, fallbackGroupId: String) {
        switch kind {
        case .movie:
            if let summary = decodeMovieSummary(record: record) {
                print("[Push] ✅ fetched Movie \(summary)")
            } else {
                print("[Push] ✅ fetched Movie recordID=\(record.recordID.recordName) (no payload decode)")
            }

        case .rating:
            if let summary = decodeRatingSummary(record: record) {
                print("[Push] ✅ fetched Rating \(summary)")
            } else {
                print("[Push] ✅ fetched Rating recordID=\(record.recordID.recordName) (no payload decode)")
            }

        case .movieNightActivity:
            if let summary = decodeMovieNightActivitySummary(record: record, fallbackGroupId: fallbackGroupId) {
                print("[Push] ✅ fetched MovieNightActivity \(summary)")
            } else {
                print("[Push] ✅ fetched MovieNightActivity recordID=\(record.recordID.recordName)")
            }
        }
    }

    private static func decodeMovieSummary(record: CKRecord) -> String? {
        // CloudKitMovieStore uses: payload(Data) + groupId(String) + updatedAt(Date)
        guard let data = record["payload"] as? Data else { return nil }
        guard let movie = try? JSONDecoder().decode(Movie.self, from: data) else { return nil }
        let gid = (record["groupId"] as? String) ?? movie.groupId ?? ""
        let updated = (record["updatedAt"] as? Date)
        let updatedPart = updated.map { " updatedAt=\($0)" } ?? ""
        return "id=\(movie.id.uuidString) title=\(movie.title) groupId=\(gid)\(updatedPart)"
    }

    private static func decodeRatingSummary(record: CKRecord) -> String? {
        // CloudKitRatingStore uses: payload(Data) + groupId(String) + movieId(String)
        guard let data = record["payload"] as? Data else { return nil }
        guard let rating = try? JSONDecoder().decode(Rating.self, from: data) else { return nil }

        let gid = (record["groupId"] as? String) ?? ""
        let movieId = (record["movieId"] as? String) ?? "(nil)"

        let score10: String = {
            if let f = rating.fazitScore { return String(f) }
            let approx = Int((rating.averageScoreNormalizedTo10).rounded())
            return String(approx)
        }()

        return "id=\(rating.id.uuidString) score10=\(score10) movieId=\(movieId) reviewer=\(rating.reviewerName) groupId=\(gid)"
    }

    private static func decodeMovieNightActivitySummary(record: CKRecord, fallbackGroupId: String) -> String? {
        // Mirrors CloudKitMovieNightStore.decodeActivity (kept local for minimal dependencies).
        let groupId = (record["groupId"] as? String) ?? fallbackGroupId
        guard
            let kindRaw = record["kind"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let eventId = record["eventId"] as? String,
            let eventStart = record["eventStart"] as? Date,
            let actorName = record["actorName"] as? String
        else { return nil }

        let decision = record["decision"] as? String
        let newStatus = record["newStatus"] as? String
        let note = record["note"] as? String

        var parts: [String] = []
        parts.append("id=\(record.recordID.recordName)")
        parts.append("groupId=\(groupId)")
        parts.append("kind=\(kindRaw)")
        parts.append("actor=\(actorName)")
        parts.append("eventId=\(eventId)")
        parts.append("eventStart=\(eventStart)")
        parts.append("createdAt=\(createdAt)")
        if let decision { parts.append("decision=\(decision)") }
        if let newStatus { parts.append("newStatus=\(newStatus)") }
        if let note, !note.isEmpty { parts.append("note=\(note)") }
        return parts.joined(separator: " ")
    }
}
