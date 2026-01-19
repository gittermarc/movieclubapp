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

    // MARK: - Phase 2: Inkrementelle Zone-Changes (Sharing-Gruppen)

    struct MovieChanges {
        let changed: [CloudMovieEntry]
        let deletedMovieIDs: [UUID]
        /// true wenn `previousToken == nil` (also ein "voller" Initial-Fetch innerhalb der Zone).
        let isInitial: Bool
    }

    /// Holt Aenderungen fuer Sharing-Gruppen inkrementell via `CKFetchRecordZoneChangesOperation`.
    ///
    /// - For legacy/public groups (ohne Zone) wird ein leerer Delta-Container zurueckgegeben.
    ///   (In diesen Faellen bleibt der bestehende Query-Pfad aktiv.)
    func fetchMovieChanges(forGroupId groupId: String?) async throws -> MovieChanges {
        guard let gid = groupId, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
            return MovieChanges(changed: [], deletedMovieIDs: [], isInitial: false)
        }

        let route = routedDatabase(forGroupId: gid)
        guard let zoneID = route.zoneID else {
            return MovieChanges(changed: [], deletedMovieIDs: [], isInitial: false)
        }

        let scope: CloudKitZoneChangeTokenStore.Scope = (ctx.scope == .shared) ? .shared : .private
        let namespace = "movies"
        let previous = CloudKitZoneChangeTokenStore.token(namespace: namespace, scope: scope, zoneID: zoneID)

        let result = try await CloudKitZoneChanges.fetchAllChanges(database: route.db, zoneID: zoneID, previousToken: previous)

        // Persist new token (even if nil; best-effort)
        CloudKitZoneChangeTokenStore.setToken(result.newChangeToken, namespace: namespace, scope: scope, zoneID: zoneID)

        // Decode only Movie records
        var changed: [CloudMovieEntry] = []
        changed.reserveCapacity(result.changedRecords.count)
        for record in result.changedRecords where record.recordType == recordType {
            if let entry = try decodeMovie(from: record) {
                changed.append(entry)
            }
        }

        // Only deletes for Movie type
        var deleted: [UUID] = []
        deleted.reserveCapacity(result.deletedRecordIDs.count)
        for rid in result.deletedRecordIDs {
            guard result.deletedRecordTypesByID[rid] == recordType else { continue }
            if let uuid = UUID(uuidString: rid.recordName) {
                deleted.append(uuid)
            }
        }

        return MovieChanges(changed: changed, deletedMovieIDs: deleted, isInitial: (previous == nil))
    }

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

    // MARK: - Merge helpers (3-way merge)

    private func sanitizedMovieForCloud(_ movie: Movie) -> Movie {
        var m = movie
        m.ratings = []
        return m
    }

    private func decodeMoviePayload(from record: CKRecord) throws -> Movie? {
        guard let data = record[payloadKey] as? Data else {
            return nil
        }

        var decoded = try JSONDecoder().decode(Movie.self, from: data)
        decoded.ratings = []

        // Prefer groupId from record field if present (payload can be legacy/empty).
        if let gid = record[groupIdKey] as? String, !gid.isEmpty {
            decoded.groupId = gid
        }

        return decoded
    }

    private func mergeRequired<T: Equatable>(ancestor: T, server: T, client: T) -> T {
        let clientChanged = client != ancestor
        let serverChanged = server != ancestor

        switch (clientChanged, serverChanged) {
        case (false, false):
            return server
        case (true, false):
            return client
        case (false, true):
            return server
        case (true, true):
            // True conflict (both changed differently): server wins to avoid overwriting others.
            return (client == server) ? server : server
        }
    }

    private func mergeOptional<T: Equatable>(ancestor: T?, server: T?, client: T?) -> T? {
        let clientChanged = client != ancestor
        let serverChanged = server != ancestor

        switch (clientChanged, serverChanged) {
        case (false, false):
            return server
        case (true, false):
            return client
        case (false, true):
            return server
        case (true, true):
            if client == server { return server }
            // If one side is missing, keep the other. Otherwise: server wins (safer; avoids overwriting others).
            if server == nil { return client }
            if client == nil { return server }
            return server
        }
    }

    private func mergeArray<T: Hashable>(ancestor: [T]?, server: [T]?, client: [T]?) -> [T]? {
        let a = ancestor ?? []
        let s = server ?? []
        let c = client ?? []

        let clientChanged = Set(c) != Set(a)
        let serverChanged = Set(s) != Set(a)

        switch (clientChanged, serverChanged) {
        case (false, false):
            return s.isEmpty ? nil : s
        case (true, false):
            return c.isEmpty ? nil : c
        case (false, true):
            return s.isEmpty ? nil : s
        case (true, true):
            // Both changed: union (server order first, then client extras).
            var out = s
            var seen = Set(out)
            for v in c where !seen.contains(v) {
                out.append(v)
                seen.insert(v)
            }
            return out.isEmpty ? nil : out
        }
    }

    private func mergeMovies(
        ancestor: Movie?,
        server: Movie,
        client: Movie,
        forcedGroupId: String?
    ) -> Movie {
        // If we don't have an ancestor, use the server record as a stable baseline.
        let a = ancestor ?? server

        var merged = server

        // Required
        merged.title = mergeRequired(ancestor: a.title, server: server.title, client: client.title)
        merged.year  = mergeRequired(ancestor: a.year,  server: server.year,  client: client.year)

        // Optionals / scalars
        merged.tmdbRating      = mergeOptional(ancestor: a.tmdbRating, server: server.tmdbRating, client: client.tmdbRating)
        merged.posterPath      = mergeOptional(ancestor: a.posterPath, server: server.posterPath, client: client.posterPath)
        merged.watchedDate     = mergeOptional(ancestor: a.watchedDate, server: server.watchedDate, client: client.watchedDate)
        merged.watchedLocation = mergeOptional(ancestor: a.watchedLocation, server: server.watchedLocation, client: client.watchedLocation)
        merged.tmdbId          = mergeOptional(ancestor: a.tmdbId, server: server.tmdbId, client: client.tmdbId)

        merged.suggestedBy     = mergeOptional(ancestor: a.suggestedBy, server: server.suggestedBy, client: client.suggestedBy)
        merged.groupName       = mergeOptional(ancestor: a.groupName, server: server.groupName, client: client.groupName)

        // Arrays
        merged.genres     = mergeArray(ancestor: a.genres, server: server.genres, client: client.genres)
        merged.genreIds   = mergeArray(ancestor: a.genreIds, server: server.genreIds, client: client.genreIds)
        merged.keywords   = mergeArray(ancestor: a.keywords, server: server.keywords, client: client.keywords)
        merged.keywordIds = mergeArray(ancestor: a.keywordIds, server: server.keywordIds, client: client.keywordIds)
        merged.cast       = mergeArray(ancestor: a.cast, server: server.cast, client: client.cast)
        merged.directors  = mergeArray(ancestor: a.directors, server: server.directors, client: client.directors)

        // Ratings are stored separately (MovieRating records) and are not part of the Movie payload in CloudKit.
        merged.ratings = []

        // Group routing safety:
        // - record field `groupIdKey` is authoritative for Cloud routing
        // - payload value should not "jump" across groups
        if let forcedGroupId {
            merged.groupId = forcedGroupId
        }

        return merged
    }

    func save(movie: Movie, isBacklog: Bool) async throws {
        let route = routedDatabase(forGroupId: movie.groupId)
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
            } else {
                record[groupIdKey] = nil
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

        func routeKey(forGroupId gid: String?) -> (key: RouteKey, db: CKDatabase, zoneID: CKRecordZone.ID?) {
            guard let gid, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
                return (RouteKey(scope: "public", zoneName: nil, ownerName: nil), container.publicCloudDatabase, nil)
            }
            let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
            let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
            let key = RouteKey(scope: (ctx.scope == .shared) ? "shared" : "private", zoneName: ctx.zoneName, ownerName: ctx.ownerName)
            return (key, db, zoneID)
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
                groupedSaves[route.key] = (route.db, route.zoneID, [], [:])
            }

            var bucket = groupedSaves[route.key]!
            bucket.records.append(record)
            bucket.originals[recordID] = (movie: movie, isBacklog: isBacklog)
            groupedSaves[route.key] = bucket
        }

        let deleteRoute = routeKey(forGroupId: groupIdForDeletes)
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
