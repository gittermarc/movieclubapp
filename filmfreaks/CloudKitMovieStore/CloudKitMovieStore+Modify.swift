//
//  CloudKitMovieStore+Modify.swift
//  filmfreaks
//
//  Split out: save/upsert, batched modify, delete.
//

import Foundation
import CloudKit

extension CloudKitMovieStore {

    // MARK: - Speichern (Upsert)

    func save(movie: Movie, isBacklog: Bool) async throws {
        let route = try routedDatabase(forGroupId: movie.groupId)
        let recordID: CKRecord.ID
        if let zoneID = route.zoneID {
            recordID = CKRecord.ID(recordName: movie.id.uuidString, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(recordName: movie.id.uuidString)
        }

        func applyFields(on record: CKRecord, movie: Movie, isBacklog: Bool) throws -> CKRecord {
            let cleanMovie = sanitizedMovieForCloud(movie)
            let data = try JSONEncoder().encode(cleanMovie)
            record[payloadKey]   = data as CKRecordValue
            record[isBacklogKey] = isBacklog as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue

            if let gid = cleanMovie.groupId, !gid.isEmpty {
                record[groupIdKey] = gid as CKRecordValue

                // CloudKit Sharing (record sharing):
                // Make all group data records children of the group's root record,
                // so participants in a share can see and add them.
                if let zoneID = route.zoneID {
                    let rootID = CKRecord.ID(recordName: gid, zoneID: zoneID)
                    record.parent = CKRecord.Reference(recordID: rootID, action: .none)
                }
            } else {
                record[groupIdKey] = nil
                record.parent = nil
            }

            return record
        }

        var attempts = 0

        while true {
            attempts += 1

            do {
                let baseRecord: CKRecord
                do {
                    baseRecord = try await route.db.record(for: recordID)
                } catch {
                    baseRecord = CKRecord(recordType: recordType, recordID: recordID)
                }

                let recordToSave = try applyFields(on: baseRecord, movie: movie, isBacklog: isBacklog)
                _ = try await route.db.save(recordToSave)
                return

            } catch {
                guard let ckError = error as? CKError,
                      ckError.code == .serverRecordChanged,
                      let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord
                else {
                    throw error
                }

                let clientRecord = ckError.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord
                let ancestorRecord = ckError.userInfo[CKRecordChangedErrorAncestorRecordKey] as? CKRecord

                let serverMovie = (try? decodeMoviePayload(from: serverRecord)) ?? sanitizedMovieForCloud(movie)
                let clientMovie: Movie = {
                    if let clientRecord, let decoded = try? decodeMoviePayload(from: clientRecord) {
                        return decoded
                    }
                    return sanitizedMovieForCloud(movie)
                }()

                let ancestorMovie: Movie? = {
                    if let ancestorRecord {
                        return try? decodeMoviePayload(from: ancestorRecord)
                    }
                    return nil
                }()

                let mergedMovie = mergeMovies(
                    ancestor: ancestorMovie,
                    server: serverMovie,
                    client: clientMovie,
                    forcedGroupId: movie.groupId
                )

                let serverIsBacklog = (serverRecord[isBacklogKey] as? Bool) ?? false
                let clientIsBacklog = (clientRecord?[isBacklogKey] as? Bool) ?? isBacklog
                let ancestorIsBacklog = ancestorRecord?[isBacklogKey] as? Bool

                let mergedIsBacklog: Bool = {
                    if let ancestorIsBacklog {
                        return mergeRequired(ancestor: ancestorIsBacklog, server: serverIsBacklog, client: clientIsBacklog)
                    }
                    // Without an ancestor, keep server unless both happen to match.
                    return (serverIsBacklog == clientIsBacklog) ? serverIsBacklog : serverIsBacklog
                }()

                let mergedRecord = try applyFields(on: serverRecord, movie: mergedMovie, isBacklog: mergedIsBacklog)

                do {
                    _ = try await route.db.save(mergedRecord)
                    return
                } catch {
                    if let second = error as? CKError,
                       second.code == .serverRecordChanged,
                       attempts < 3 {
                        continue
                    }
                    throw error
                }
            }
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

        func routeKey(forGroupId gid: String?) throws -> (key: RouteKey, db: CKDatabase, zoneID: CKRecordZone.ID?) {
            if let normalized = CloudKitRouting.normalizedGroupId(gid),
               let ctx = GroupContextStore.context(forGroupId: normalized) {
                let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
                let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
                let key = RouteKey(
                    scope: (ctx.scope == .shared) ? "shared" : "private",
                    zoneName: ctx.zoneName,
                    ownerName: ctx.ownerName
                )
                return (key, db, zoneID)
            }

            // Safety: validate that we are allowed to fall back to Public DB.
            // (UUID-like groupIds without GroupContext will throw.)
            _ = try CloudKitRouting.route(container: container, groupId: gid)
            return (RouteKey(scope: "public", zoneName: nil, ownerName: nil), container.publicCloudDatabase, nil)
        }

        // We keep a mapping from CKRecord.ID -> (Movie,isBacklog) so that we can
        // resolve `serverRecordChanged` conflicts by falling back to the 3-way merge in `save(movie:isBacklog:)`.
        var groupedSaves: [RouteKey: (
            db: CKDatabase,
            zoneID: CKRecordZone.ID?,
            records: [CKRecord],
            originals: [CKRecord.ID: (movie: Movie, isBacklog: Bool)]
        )] = [:]
        groupedSaves.reserveCapacity(3)

        for (movie, isBacklog) in saveItems {
            let gid = movie.groupId
            let route = try routeKey(forGroupId: gid)
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

                // CloudKit Sharing: attach the record as child of the group's root record.
                if let zoneID = route.zoneID {
                    let rootID = CKRecord.ID(recordName: gid, zoneID: zoneID)
                    record.parent = CKRecord.Reference(recordID: rootID, action: .none)
                }
            } else {
                record[groupIdKey] = nil
                record.parent = nil
            }

            if groupedSaves[route.key] == nil {
                groupedSaves[route.key] = (route.db, route.zoneID, [], [:])
            }

            var bucket = groupedSaves[route.key]!
            bucket.records.append(record)
            bucket.originals[recordID] = (movie: movie, isBacklog: isBacklog)
            groupedSaves[route.key] = bucket
        }

        let deleteRoute = try routeKey(forGroupId: groupIdForDeletes)
        let deleteRecordIDs: [CKRecord.ID] = deleteIDs.map { id in
            if let zoneID = deleteRoute.zoneID {
                return CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
            }
            return CKRecord.ID(recordName: id.uuidString)
        }

        let maxPerOp = 200

        func handleSaveFailure(_ error: Error, originalsByID: [CKRecord.ID: (movie: Movie, isBacklog: Bool)]) async throws {
            guard let ck = error as? CKError else { throw error }

            // Most common: partial failure (some records succeeded, some failed)
            if ck.code == .partialFailure,
               let perItem = ck.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {

                var firstNonConflict: Error?

                for (recordID, itemError) in perItem {
                    if let itemCK = itemError as? CKError, itemCK.code == .serverRecordChanged,
                       let original = originalsByID[recordID] {
                        // Resolve by saving individually with 3-way merge.
                        try await self.save(movie: original.movie, isBacklog: original.isBacklog)
                    } else {
                        // Preserve the first non-conflict error.
                        if firstNonConflict == nil {
                            firstNonConflict = itemError
                        }
                    }
                }

                if let firstNonConflict {
                    throw firstNonConflict
                }

                return
            }

            // Rare: operation-level serverRecordChanged. Fall back to individual saves.
            if ck.code == .serverRecordChanged {
                for (_, original) in originalsByID {
                    try await self.save(movie: original.movie, isBacklog: original.isBacklog)
                }
                return
            }

            throw error
        }

        for (_, bucket) in groupedSaves {
            let records = bucket.records
            if records.isEmpty { continue }

            var start = 0
            while start < records.count {
                let end = min(start + maxPerOp, records.count)
                let slice = Array(records[start..<end])

                // Build recordID -> original mapping for this slice.
                var originalsByID: [CKRecord.ID: (movie: Movie, isBacklog: Bool)] = [:]
                originalsByID.reserveCapacity(slice.count)
                for r in slice {
                    if let original = bucket.originals[r.recordID] {
                        originalsByID[r.recordID] = original
                    }
                }

                do {
                    try await modifyRecords(database: bucket.db, saving: slice, deleting: [])
                } catch {
                    try await handleSaveFailure(error, originalsByID: originalsByID)
                }

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
        let route = try routedDatabase(forGroupId: groupId)
        let recordID: CKRecord.ID
        if let zoneID = route.zoneID {
            recordID = CKRecord.ID(recordName: movieID.uuidString, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(recordName: movieID.uuidString)
        }
        _ = try await route.db.deleteRecord(withID: recordID)
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
