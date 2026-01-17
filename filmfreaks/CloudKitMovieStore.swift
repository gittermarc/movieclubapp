//
//  CloudKitMovieStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.12.25.
//

import Foundation
import CloudKit

/// Hilfs-Typ, damit wir aus CloudKit nicht nur den Film,
/// sondern auch die Info "Backlog oder gesehen?" zurückbekommen.
struct CloudMovieEntry {
    let movie: Movie
    let isBacklog: Bool
}

/// Kapselt alle Zugriffe auf CloudKit für Movie-Objekte.
struct CloudKitMovieStore {

    private let container: CKContainer

    private let recordType   = "Movie"       // Record-Typ in CloudKit
    private let payloadKey   = "payload"     // Data (codierter Movie)
    private let isBacklogKey = "isBacklog"   // Bool
    private let updatedAtKey = "updatedAt"   // Date
    private let groupIdKey   = "groupId"     // String: aktuelle Gruppen-ID (Invite-Code) oder leer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Routing (Legacy Public DB vs. Sharing Private/Shared DB)

    private func routedDatabase(forGroupId groupId: String?) -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        guard let gid = groupId, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
            return (container.publicCloudDatabase, nil)
        }

        let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
        let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
        return (db, zoneID)
    }

    // MARK: - Laden

    func fetchMovies(forGroupId groupId: String?) async throws -> [CloudMovieEntry] {
        if let gid = groupId, !gid.isEmpty, GroupContextStore.context(forGroupId: gid) != nil {
            let route = routedDatabase(forGroupId: gid)
            let predicate = NSPredicate(format: "%K == %@", groupIdKey, gid)
            return try await fetchMovies(with: predicate, database: route.db, zoneID: route.zoneID)
        }

        if let groupId, !groupId.isEmpty {
            let fastPredicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)
            let fastEntries = try await fetchMovies(with: fastPredicate, database: container.publicCloudDatabase, zoneID: nil)
            if !fastEntries.isEmpty {
                return fastEntries
            }

            return try await migrateLegacyGroupIdFieldAndFetch(forGroupId: groupId)
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

    // MARK: - Speichern (Upsert)

    func save(movie: Movie, isBacklog: Bool) async throws {
        let route = routedDatabase(forGroupId: movie.groupId)
        let recordID: CKRecord.ID
        if let zoneID = route.zoneID {
            recordID = CKRecord.ID(recordName: movie.id.uuidString, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(recordName: movie.id.uuidString)
        }

        func applyFields(on record: CKRecord) throws -> CKRecord {
            var movieForCloud = movie
            movieForCloud.ratings = []
            let data = try JSONEncoder().encode(movieForCloud)
            record[payloadKey]   = data as CKRecordValue
            record[isBacklogKey] = isBacklog as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue

            if let gid = movie.groupId, !gid.isEmpty {
                record[groupIdKey] = gid as CKRecordValue
            } else {
                record[groupIdKey] = nil
            }
            return record
        }

        do {
            let baseRecord: CKRecord
            do {
                baseRecord = try await route.db.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: recordType, recordID: recordID)
            }

            let recordToSave = try applyFields(on: baseRecord)
            _ = try await route.db.save(recordToSave)

        } catch {
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                let updatedRecord = try applyFields(on: serverRecord)

                do {
                    _ = try await route.db.save(updatedRecord)
                } catch {
                    if let second = error as? CKError,
                       second.code == .serverRecordChanged {
                        return
                    } else {
                        throw error
                    }
                }
                return
            }

            throw error
        }
    }

    // MARK: - Batched modify (Phase 2)

    func modifyBatch(
        saveItems: [(Movie, Bool)],
        deleteIDs: [UUID],
        groupIdForDeletes: String?
    ) async throws {
        struct RouteKey: Hashable {
            let scope: String
            let zoneName: String?
            let ownerName: String?
        }

        func routeKey(forGroupId gid: String?) -> (key: RouteKey, db: CKDatabase, zoneID: CKRecordZone.ID?) {
            guard let gid, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
                return (RouteKey(scope: "public", zoneName: nil, ownerName: nil), container.publicCloudDatabase, nil)
            }
            let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
            let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
            let key = RouteKey(scope: (ctx.scope == .shared) ? "shared" : "private", zoneName: ctx.zoneName, ownerName: ctx.ownerName)
            return (key, db, zoneID)
        }

        var groupedSaves: [RouteKey: (db: CKDatabase, zoneID: CKRecordZone.ID?, records: [CKRecord])] = [:]
        groupedSaves.reserveCapacity(3)

        for (movie, isBacklog) in saveItems {
            let gid = movie.groupId
            let route = routeKey(forGroupId: gid)
            let recordID: CKRecord.ID = {
                if let zoneID = route.zoneID {
                    return CKRecord.ID(recordName: movie.id.uuidString, zoneID: zoneID)
                }
                return CKRecord.ID(recordName: movie.id.uuidString)
            }()

            // ✅ warning fix: `let` is fine (CKRecord is a reference type)
            let record = CKRecord(recordType: recordType, recordID: recordID)

            var movieForCloud = movie
            movieForCloud.ratings = []
            let data = try JSONEncoder().encode(movieForCloud)
            record[payloadKey] = data as CKRecordValue
            record[isBacklogKey] = isBacklog as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue

            if let gid, !gid.isEmpty {
                record[groupIdKey] = gid as CKRecordValue
            } else {
                record[groupIdKey] = nil
            }

            if groupedSaves[route.key] == nil {
                groupedSaves[route.key] = (route.db, route.zoneID, [])
            }
            groupedSaves[route.key]?.records.append(record)
        }

        let deleteRoute = routeKey(forGroupId: groupIdForDeletes)
        let deleteRecordIDs: [CKRecord.ID] = deleteIDs.map { id in
            if let zoneID = deleteRoute.zoneID {
                return CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
            }
            return CKRecord.ID(recordName: id.uuidString)
        }

        let maxPerOp = 200

        for (_, bucket) in groupedSaves {
            let records = bucket.records
            if records.isEmpty { continue }

            var start = 0
            while start < records.count {
                let end = min(start + maxPerOp, records.count)
                let slice = Array(records[start..<end])
                try await modifyRecords(database: bucket.db, saving: slice, deleting: [])
                start = end
            }
        }

        if !deleteRecordIDs.isEmpty {
            var start = 0
            while start < deleteRecordIDs.count {
                let end = min(start + maxPerOp, deleteRecordIDs.count)
                let slice = Array(deleteRecordIDs[start..<end])
                try await modifyRecords(database: deleteRoute.db, saving: [], deleting: slice)
                start = end
            }
        }
    }

    // MARK: - Löschen

    func delete(movieID: UUID, groupId: String?) async throws {
        let route = routedDatabase(forGroupId: groupId)
        let recordID: CKRecord.ID
        if let zoneID = route.zoneID {
            recordID = CKRecord.ID(recordName: movieID.uuidString, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(recordName: movieID.uuidString)
        }
        _ = try await route.db.deleteRecord(withID: recordID)
    }

    // MARK: - Hilfsfunktion: Record → Movie

    private func decodeMovie(from record: CKRecord) throws -> CloudMovieEntry? {
        guard let data = record[payloadKey] as? Data else {
            return nil
        }

        var decoded = try JSONDecoder().decode(Movie.self, from: data)
        decoded.ratings = []
        let isBacklog = (record[isBacklogKey] as? Bool) ?? false

        if let gid = record[groupIdKey] as? String, !gid.isEmpty {
            decoded.groupId = gid
        }

        return CloudMovieEntry(movie: decoded, isBacklog: isBacklog)
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

// MARK: - CloudKit async helper (completion -> async)

private func modifyRecords(database: CKDatabase, saving: [CKRecord], deleting: [CKRecord.ID]) async throws {
    try await withCheckedThrowingContinuation { cont in
        let op = CKModifyRecordsOperation(recordsToSave: saving, recordIDsToDelete: deleting)
        op.savePolicy = .changedKeys
        op.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                cont.resume(returning: ())
            case .failure(let error):
                cont.resume(throwing: error)
            }
        }
        database.add(op)
    }
}
