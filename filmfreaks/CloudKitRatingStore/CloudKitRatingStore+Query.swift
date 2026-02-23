//
//  CloudKitRatingStore+Query.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

extension CloudKitRatingStore {

    // MARK: - Fetch

    /// Lädt alle Ratings für eine Gruppe (und optional gefiltert auf Movie-IDs).
    /// Rückgabe: [movieUUID: [Rating]]
    func fetchRatings(forGroupId groupId: String?, movieIds: [UUID]? = nil) async throws -> [UUID: [Rating]] {
        let route = try routedDatabase(forGroupId: groupId)

        let predicate: NSPredicate
        if let gid = groupId, !gid.isEmpty {
            predicate = NSPredicate(format: "%K == %@", Schema.groupIdKey, gid)
        } else {
            // "Keine Gruppe": alte/default Daten – wir akzeptieren alle ohne groupId Feld
            predicate = NSPredicate(format: "%K == NULL", Schema.groupIdKey)
        }

        // Optional zusätzlich auf Movie-IDs filtern (in Chunks)
        if let movieIds, !movieIds.isEmpty {
            return try await fetchRatingsChunked(database: route.db, zoneID: route.zoneID, groupPredicate: predicate, movieIds: movieIds, groupId: groupId)
        } else {
            let records = try await fetchRecords(database: route.db, zoneID: route.zoneID, predicate: predicate)
            return try decode(records: records, groupId: groupId)
        }
    }

    private func fetchRatingsChunked(database: CKDatabase, zoneID: CKRecordZone.ID?, groupPredicate: NSPredicate, movieIds: [UUID], groupId: String?) async throws -> [UUID: [Rating]] {
        var merged: [UUID: [Rating]] = [:]
        let chunkSize = 100

        var start = 0
        while start < movieIds.count {
            let end = min(movieIds.count, start + chunkSize)
            let chunk = movieIds[start..<end].map { $0.uuidString }
            let chunkPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                groupPredicate,
                NSPredicate(format: "%K IN %@", Schema.movieIdKey, Array(chunk))
            ])

            let records = try await fetchRecords(database: database, zoneID: zoneID, predicate: chunkPredicate)
            let decoded = try decode(records: records, groupId: groupId)
            merged = merge(dictA: merged, dictB: decoded)

            start = end
        }

        return merged
    }

    private func fetchRecords(database: CKDatabase, zoneID: CKRecordZone.ID?, predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: Schema.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Schema.updatedAtKey, ascending: false)]
        return try await queryAllRecords(database: database, query: query, zoneID: zoneID)
    }

    private func decode(records: [CKRecord], groupId: String?) throws -> [UUID: [Rating]] {
        var dict: [UUID: [Rating]] = [:]

        for record in records {
            guard
                let movieIdString = record[Schema.movieIdKey] as? String,
                let uuid = UUID(uuidString: movieIdString),
                let data = record[Schema.payloadKey] as? Data
            else { continue }

            var rating = try JSONDecoder().decode(Rating.self, from: data)

            // Timestamp from the CloudKit record (authoritative).
            rating.updatedAt = record[Schema.updatedAtKey] as? Date

            // Backfill reviewerId if missing in payload (legacy records)
            if rating.reviewerId == nil {
                if let ridString = record[Schema.reviewerIdKey] as? String,
                   let rid = UUID(uuidString: ridString) {
                    rating.reviewerId = rid
                } else if let gid = groupId, !gid.isEmpty {
                    rating.reviewerId = StableID.deterministicUUID(forName: rating.reviewerName, groupId: gid)
                }
            }

            dict[uuid, default: []].append(rating)
        }

        // Stabil: pro Movie nach Reviewer uniq (falls Duplikate existieren)
        for (k, list) in dict {
            dict[k] = uniqByReviewer(list)
        }

        return dict
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
