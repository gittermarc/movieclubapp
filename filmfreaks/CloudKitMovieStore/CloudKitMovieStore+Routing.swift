//
//  CloudKitMovieStore+Routing.swift
//  filmfreaks
//
//  Split out: routing + fetch/query + legacy migration.
//

import Foundation
import CloudKit

extension CloudKitMovieStore {

    // MARK: - Routing (Legacy Public DB vs. Sharing Private/Shared DB)

    func routedDatabase(forGroupId groupId: String?) throws -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        try CloudKitRouting.route(container: container, groupId: groupId)
    }

    // MARK: - Laden

    func fetchMovies(forGroupId groupId: String?) async throws -> [CloudMovieEntry] {
        if let gid = CloudKitRouting.normalizedGroupId(groupId) {
            // Safety: UUID-like groupIds must not fall back to Public DB.
            // (route(...) throws if GroupContext is missing.)
            let route = try routedDatabase(forGroupId: gid)

            // Zone-based group: query inside the zone.
            if route.zoneID != nil {
                let predicate = NSPredicate(format: "%K == %@", groupIdKey, gid)
                return try await fetchMovies(with: predicate, database: route.db, zoneID: route.zoneID)
            }

            // Legacy/public group: query Public DB and optionally migrate legacy groupId-in-payload.
            let fastPredicate = NSPredicate(format: "%K == %@", groupIdKey, gid)
            let fastEntries = try await fetchMovies(with: fastPredicate, database: container.publicCloudDatabase, zoneID: nil)
            if !fastEntries.isEmpty {
                return fastEntries
            }

            return try await migrateLegacyGroupIdFieldAndFetch(forGroupId: gid)
        }

        let predicate = NSPredicate(format: "%K == NULL OR %K == ''", groupIdKey, groupIdKey)
        let entries = try await fetchMovies(with: predicate, database: container.publicCloudDatabase, zoneID: nil)
        return entries.filter { ($0.movie.groupId?.isEmpty ?? true) }
    }

    // MARK: - Legacy Migration

    private func migrateLegacyGroupIdFieldAndFetch(forGroupId groupId: String) async throws -> [CloudMovieEntry] {
        let legacyPredicate = NSPredicate(format: "%K == NULL OR %K == ''", groupIdKey, groupIdKey)
        let legacyRecords = try await fetchRecords(with: legacyPredicate, database: container.publicCloudDatabase, zoneID: nil)
        if legacyRecords.isEmpty {
            return []
        }

        struct Candidate {
            let record: CKRecord
            let entry: CloudMovieEntry
        }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(legacyRecords.count)

        for record in legacyRecords {
            do {
                guard let entry = try decodeMovie(from: record) else { continue }
                if entry.movie.groupId == groupId {
                    candidates.append(Candidate(record: record, entry: entry))
                }
            } catch {
                print("CloudKit legacy decode error: \(error)")
            }
        }

        if candidates.isEmpty {
            return []
        }

        await withTaskGroup(of: Void.self) { group in
            for c in candidates {
                group.addTask {
                    do {
                        try await self.saveLegacyMigration(recordID: c.record.recordID, groupId: groupId)
                    } catch {
                        print("CloudKit legacy migration save error: \(error)")
                    }
                }
            }
            await group.waitForAll()
        }

        return candidates.map { $0.entry }
    }

    private func saveLegacyMigration(recordID: CKRecord.ID, groupId: String) async throws {
        func applyFields(on record: CKRecord) -> CKRecord {
            record[groupIdKey] = groupId as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let base = try await container.publicCloudDatabase.record(for: recordID)
            let recordToSave = applyFields(on: base)
            _ = try await container.publicCloudDatabase.save(recordToSave)
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let updated = applyFields(on: serverRecord)
                _ = try await container.publicCloudDatabase.save(updated)
                return
            }
            throw error
        }
    }

    // MARK: - Query Helpers

    private func fetchRecords(with predicate: NSPredicate, database: CKDatabase, zoneID: CKRecordZone.ID?) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        return try await queryAllRecords(database: database, query: query, zoneID: zoneID)
    }

    private func fetchMovies(with predicate: NSPredicate, database: CKDatabase, zoneID: CKRecordZone.ID?) async throws -> [CloudMovieEntry] {
        let records = try await fetchRecords(with: predicate, database: database, zoneID: zoneID)
        var entries: [CloudMovieEntry] = []
        entries.reserveCapacity(records.count)

        for record in records {
            if let entry = try decodeMovie(from: record) {
                entries.append(entry)
            }
        }

        return entries
    }
}

// MARK: - Zone-aware query helper

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
