//
//  CloudKitMovieNightStore+Snapshot.swift
//  filmfreaks
//
//  Split from CloudKitMovieNightStore.swift (P0.3)
//

import Foundation
import CloudKit

extension CloudKitMovieNightStore {

    // MARK: - Full snapshot (legacy/public groups)

    struct MovieNightSnapshot {
        let events: [MovieNightEvent]
        let responses: [MovieNightResponse]
        let activity: [MovieNightActivityEvent]
        let presets: [MovieRoulettePreset]
    }

    /// Loads a full snapshot via queries (used for public/legacy groups).
    ///
    /// - Note: For zone-based groups we prefer `fetchMovieNightChanges`.
    func fetchMovieNightSnapshot(forGroupId groupId: String) async throws -> MovieNightSnapshot {
        let route = try routedDatabase(forGroupId: groupId)

        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)

        let events = try await fetchAllEvents(predicate: predicate, database: route.db, zoneID: route.zoneID, fallbackGroupId: groupId)
        let responses = try await fetchAllResponses(predicate: predicate, database: route.db, zoneID: route.zoneID)
        let activity = try await fetchAllActivity(predicate: predicate, database: route.db, zoneID: route.zoneID, fallbackGroupId: groupId)
        let presets = try await fetchAllPresets(predicate: predicate, database: route.db, zoneID: route.zoneID, fallbackGroupId: groupId)

        return MovieNightSnapshot(events: events, responses: responses, activity: activity, presets: presets)
    }

    // MARK: - Query helpers (snapshot)

    func fetchAllEvents(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?,
        fallbackGroupId: String
    ) async throws -> [MovieNightEvent] {
        let query = CKQuery(recordType: eventRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodeEvent(record: $0, fallbackGroupId: fallbackGroupId) }
    }

    func fetchAllResponses(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?
    ) async throws -> [MovieNightResponse] {
        let query = CKQuery(recordType: responseRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodeResponse(record: $0) }
    }

    func fetchAllActivity(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?,
        fallbackGroupId: String
    ) async throws -> [MovieNightActivityEvent] {
        let query = CKQuery(recordType: activityRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodeActivity(record: $0, fallbackGroupId: fallbackGroupId) }
    }


    func fetchAllPresets(
        predicate: NSPredicate,
        database: CKDatabase,
        zoneID: CKRecordZone.ID?,
        fallbackGroupId: String
    ) async throws -> [MovieRoulettePreset] {
        let query = CKQuery(recordType: presetRecordType, predicate: predicate)
        let records = try await queryAllRecords(database: database, query: query, zoneID: zoneID)
        return records.compactMap { decodePreset(record: $0, fallbackGroupId: fallbackGroupId) }
    }

    func queryAllRecords(database: CKDatabase, query: CKQuery, zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
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
}
