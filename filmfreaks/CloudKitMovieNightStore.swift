//
//  CloudKitMovieNightStore.swift
//  filmfreaks
//
//  Phase 3 (Movie Nights): Cloud read support.
//

import Foundation
import CloudKit

/// Kapselt alle CloudKit-Lesezugriffe fuer Filmabende.
///
/// Phase 3 ist bewusst *read-only*: Wir laden Daten aus iCloud und mergen sie
/// in den lokalen JSON-Snapshot (`MovieNightLocalPersistence`).
/// Writes/Deletes kommen in Schritt 4.
struct CloudKitMovieNightStore {

    // MARK: - CloudKit Setup

    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    private func routedDatabase(forGroupId groupId: String) -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        guard let ctx = GroupContextStore.context(forGroupId: groupId) else {
            return (container.publicCloudDatabase, nil)
        }

        let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
        let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
        return (db, zoneID)
    }

    // MARK: - Schema

    // Record Types
    private let eventRecordType = "MovieNightEvent"
    private let responseRecordType = "MovieNightResponse"
    private let activityRecordType = "MovieNightActivity"

    // Common keys
    private let groupIdKey = "groupId"

    // Event keys
    private let proposedStartKey = "proposedStart"
    private let createdAtKey = "createdAt"
    private let updatedAtKey = "updatedAt"
    private let proposerUserIdKey = "proposerUserId"
    private let proposerNameKey = "proposerName"
    private let noteKey = "note"
    private let statusKey = "status"

    // Response keys
    private let eventIdKey = "eventId"
    private let userIdKey = "userId"
    private let userNameKey = "userName"
    private let decisionKey = "decision"
    private let respondedAtKey = "respondedAt"

    // Activity keys
    private let kindKey = "kind"
    private let eventStartKey = "eventStart"
    private let actorUserIdKey = "actorUserId"
    private let actorNameKey = "actorName"
    private let newStatusKey = "newStatus"

    // MARK: - Zone changes (Sharing-Gruppen)

    struct MovieNightChanges {
        let changedEvents: [MovieNightEvent]
        let deletedEventIDs: [UUID]

        let changedResponses: [MovieNightResponse]
        /// composite response ids as defined by `MovieNightResponse.id`.
        let deletedResponseIDs: [String]

        let changedActivity: [MovieNightActivityEvent]
        let deletedActivityIDs: [UUID]

        let isInitial: Bool
    }

    /// Holt inkrementelle Aenderungen fuer Zone-basierte Gruppen.
    ///
    /// Fuer legacy/public groups (ohne GroupContext/Zone) wird ein leeres Delta zurueckgegeben.
    func fetchMovieNightChanges(forGroupId groupId: String) async throws -> MovieNightChanges {
        guard let ctx = GroupContextStore.context(forGroupId: groupId) else {
            return MovieNightChanges(
                changedEvents: [], deletedEventIDs: [],
                changedResponses: [], deletedResponseIDs: [],
                changedActivity: [], deletedActivityIDs: [],
                isInitial: false
            )
        }

        let route = routedDatabase(forGroupId: groupId)
        guard let zoneID = route.zoneID else {
            return MovieNightChanges(
                changedEvents: [], deletedEventIDs: [],
                changedResponses: [], deletedResponseIDs: [],
                changedActivity: [], deletedActivityIDs: [],
                isInitial: false
            )
        }

        let scope: CloudKitZoneChangeTokenStore.Scope = (ctx.scope == .shared) ? .shared : .private
        let namespace = "movieNights"
        let previous = CloudKitZoneChangeTokenStore.token(namespace: namespace, scope: scope, zoneID: zoneID)

        let result = try await CloudKitZoneChanges.fetchAllChanges(database: route.db, zoneID: zoneID, previousToken: previous)
        CloudKitZoneChangeTokenStore.setToken(result.newChangeToken, namespace: namespace, scope: scope, zoneID: zoneID)

        var changedEvents: [MovieNightEvent] = []
        var changedResponses: [MovieNightResponse] = []
        var changedActivity: [MovieNightActivityEvent] = []

        changedEvents.reserveCapacity(16)
        changedResponses.reserveCapacity(16)
        changedActivity.reserveCapacity(16)

        for record in result.changedRecords {
            switch record.recordType {
            case eventRecordType:
                if let e = decodeEvent(record: record, fallbackGroupId: groupId) {
                    changedEvents.append(e)
                }
            case responseRecordType:
                if let r = decodeResponse(record: record) {
                    changedResponses.append(r)
                }
            case activityRecordType:
                if let a = decodeActivity(record: record, fallbackGroupId: groupId) {
                    changedActivity.append(a)
                }
            default:
                break
            }
        }

        var deletedEventIDs: [UUID] = []
        var deletedResponseIDs: [String] = []
        var deletedActivityIDs: [UUID] = []

        deletedEventIDs.reserveCapacity(8)
        deletedResponseIDs.reserveCapacity(8)
        deletedActivityIDs.reserveCapacity(8)

        for rid in result.deletedRecordIDs {
            guard let type = result.deletedRecordTypesByID[rid] else { continue }
            switch type {
            case eventRecordType:
                if let uuid = UUID(uuidString: rid.recordName) { deletedEventIDs.append(uuid) }
            case activityRecordType:
                if let uuid = UUID(uuidString: rid.recordName) { deletedActivityIDs.append(uuid) }
            case responseRecordType:
                if let parsed = parseResponseRecordName(rid.recordName) {
                    deletedResponseIDs.append(MovieNightResponse.compositeId(eventId: parsed.eventId, userId: parsed.userId))
                }
            default:
                break
            }
        }

        return MovieNightChanges(
            changedEvents: changedEvents,
            deletedEventIDs: deletedEventIDs,
            changedResponses: changedResponses,
            deletedResponseIDs: deletedResponseIDs,
            changedActivity: changedActivity,
            deletedActivityIDs: deletedActivityIDs,
            isInitial: (previous == nil)
        )
    }

    // MARK: - Full snapshot (legacy/public groups)

    struct MovieNightSnapshot {
        let events: [MovieNightEvent]
        let responses: [MovieNightResponse]
        let activity: [MovieNightActivityEvent]
    }

    /// Loads a full snapshot via queries (used for public/legacy groups).
    ///
    /// - Note: For zone-based groups we prefer `fetchMovieNightChanges`.
    func fetchMovieNightSnapshot(forGroupId groupId: String) async throws -> MovieNightSnapshot {
        let route = routedDatabase(forGroupId: groupId)

        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)

        let events = try await fetchAllEvents(predicate: predicate, database: route.db, zoneID: route.zoneID, fallbackGroupId: groupId)
        let responses = try await fetchAllResponses(predicate: predicate, database: route.db, zoneID: route.zoneID)
        let activity = try await fetchAllActivity(predicate: predicate, database: route.db, zoneID: route.zoneID, fallbackGroupId: groupId)

        return MovieNightSnapshot(events: events, responses: responses, activity: activity)
    }

    // MARK: - Decode helpers

    private func decodeEvent(record: CKRecord, fallbackGroupId: String) -> MovieNightEvent? {
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let groupId = (record[groupIdKey] as? String) ?? fallbackGroupId
        guard
            let proposedStart = record[proposedStartKey] as? Date,
            let createdAt = record[createdAtKey] as? Date,
            let updatedAt = record[updatedAtKey] as? Date,
            let proposerUserIdString = record[proposerUserIdKey] as? String,
            let proposerUserId = UUID(uuidString: proposerUserIdString),
            let proposerName = record[proposerNameKey] as? String,
            let statusRaw = record[statusKey] as? String,
            let status = MovieNightEvent.Status(rawValue: statusRaw)
        else { return nil }

        let note = record[noteKey] as? String

        return MovieNightEvent(
            id: id,
            groupId: groupId,
            proposedStart: proposedStart,
            createdAt: createdAt,
            updatedAt: updatedAt,
            proposerUserId: proposerUserId,
            proposerName: proposerName,
            note: note,
            status: status
        )
    }

    private func decodeResponse(record: CKRecord) -> MovieNightResponse? {
        guard
            let eventIdString = record[eventIdKey] as? String,
            let eventId = UUID(uuidString: eventIdString),
            let userIdString = record[userIdKey] as? String,
            let userId = UUID(uuidString: userIdString),
            let userName = record[userNameKey] as? String,
            let decisionRaw = record[decisionKey] as? String,
            let decision = MovieNightResponse.Decision(rawValue: decisionRaw),
            let respondedAt = record[respondedAtKey] as? Date
        else { return nil }

        return MovieNightResponse(
            eventId: eventId,
            userId: userId,
            userName: userName,
            decision: decision,
            respondedAt: respondedAt
        )
    }

    private func decodeActivity(record: CKRecord, fallbackGroupId: String) -> MovieNightActivityEvent? {
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let groupId = (record[groupIdKey] as? String) ?? fallbackGroupId
        guard
            let kindRaw = record[kindKey] as? String,
            let kind = MovieNightActivityEvent.Kind(rawValue: kindRaw),
            let createdAt = record[createdAtKey] as? Date,
            let eventIdString = record[eventIdKey] as? String,
            let eventId = UUID(uuidString: eventIdString),
            let eventStart = record[eventStartKey] as? Date,
            let actorUserIdString = record[actorUserIdKey] as? String,
            let actorUserId = UUID(uuidString: actorUserIdString),
            let actorName = record[actorNameKey] as? String
        else { return nil }

        let decision: MovieNightResponse.Decision? = {
            guard let raw = record[decisionKey] as? String else { return nil }
            return MovieNightResponse.Decision(rawValue: raw)
        }()

        let newStatus: MovieNightEvent.Status? = {
            guard let raw = record[newStatusKey] as? String else { return nil }
            return MovieNightEvent.Status(rawValue: raw)
        }()

        let note = record[noteKey] as? String

        return MovieNightActivityEvent(
            id: id,
            groupId: groupId,
            kind: kind,
            createdAt: createdAt,
            eventId: eventId,
            eventStart: eventStart,
            actorUserId: actorUserId,
            actorName: actorName,
            decision: decision,
            newStatus: newStatus,
            note: note
        )
    }

    // MARK: - Query helpers (snapshot)

    private func fetchAllEvents(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?,
        fallbackGroupId: String
    ) async throws -> [MovieNightEvent] {
        let query = CKQuery(recordType: eventRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodeEvent(record: $0, fallbackGroupId: fallbackGroupId) }
    }

    private func fetchAllResponses(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?
    ) async throws -> [MovieNightResponse] {
        let query = CKQuery(recordType: responseRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodeResponse(record: $0) }
    }

    private func fetchAllActivity(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?,
        fallbackGroupId: String
    ) async throws -> [MovieNightActivityEvent] {
        let query = CKQuery(recordType: activityRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodeActivity(record: $0, fallbackGroupId: fallbackGroupId) }
    }

    private func queryAllRecords(database: CKDatabase, query: CKQuery, zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { cont in
            var collected: [CKRecord] = []

            func run(cursor: CKQueryOperation.Cursor?) {
                let op: CKQueryOperation
                if let cursor {
                    op = CKQueryOperation(cursor: cursor)
                } else {
                    op = CKQueryOperation(query: query)
                    op.zoneID = zoneID
                }

                op.recordMatchedBlock = { _, result in
                    if case .success(let record) = result {
                        collected.append(record)
                    }
                }

                op.queryResultBlock = { result in
                    switch result {
                    case .success(let nextCursor):
                        if let nextCursor {
                            run(cursor: nextCursor)
                        } else {
                            cont.resume(returning: collected)
                        }
                    case .failure(let error):
                        cont.resume(throwing: error)
                    }
                }

                database.add(op)
            }

            run(cursor: nil)
        }
    }

    // MARK: - Response recordName encoding (for deletes)

    private struct ParsedResponseRecordName {
        let eventId: UUID
        let userId: UUID
    }

    private func parseResponseRecordName(_ recordName: String) -> ParsedResponseRecordName? {
        guard let raw = decodeBase64URL(recordName) else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let eventIdStr = String(parts[1])
        let userIdStr = String(parts[2])
        guard let eventId = UUID(uuidString: eventIdStr), let userId = UUID(uuidString: userIdStr) else { return nil }
        return ParsedResponseRecordName(eventId: eventId, userId: userId)
    }

    private func decodeBase64URL(_ s: String) -> String? {
        var b64 = s
        b64 = b64.replacingOccurrences(of: "-", with: "+")
        b64 = b64.replacingOccurrences(of: "_", with: "/")
        let mod = b64.count % 4
        if mod != 0 {
            b64 += String(repeating: "=", count: 4 - mod)
        }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Convenience

private extension MovieNightResponse {
    static func compositeId(eventId: UUID, userId: UUID) -> String {
        "\(eventId.uuidString)_\(userId.uuidString)"
    }
}
