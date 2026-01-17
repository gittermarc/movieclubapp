//
//  CloudKitRatingStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

/// CloudKit Store für per-User Ratings (Version B).
///
/// Jeder User ist Creator seines Rating-Records → darf ihn auch aktualisieren.
/// Andere User können die Ratings lesen.
struct CloudKitRatingStore {

    // MARK: - CloudKit Setup

    private let container: CKContainer

    private func routedDatabase(forGroupId groupId: String?) -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        guard let gid = groupId, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
            return (container.publicCloudDatabase, nil)
        }

        let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
        let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
        return (db, zoneID)
    }

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Schema

    private let recordType = "MovieRating"
    private let payloadKey = "payload"              // Data: codierter Rating
    private let movieIdKey = "movieId"              // String: UUID
    private let groupIdKey = "groupId"              // String: Group-ID
    private let reviewerIdKey = "reviewerId"        // String: UUID (stabile Identität)
    private let reviewerNameKey = "reviewerName"    // String: Display-Name (optional, Debug/Stats)
    private let updatedAtKey = "updatedAt"          // Date

    // MARK: - Helpers

    private func normalizedGroupId(_ groupId: String?) -> String {
        (groupId?.isEmpty == false) ? groupId! : "nogroup"
    }

    private func stableReviewerId(for rating: Rating, groupId: String?) -> UUID {
        if let rid = rating.reviewerId { return rid }
        guard let gid = groupId, !gid.isEmpty else {
            // Offline/no-group: best-effort deterministic based on name only is not stable on rename,
            // but offline groups are local anyway.
            return UUID()
        }
        return StableID.deterministicUUID(forName: rating.reviewerName, groupId: gid)
    }

    private func recordID(groupId: String?, movieId: UUID, reviewerId: UUID) -> CKRecord.ID {
        // Stabil & safe: base64-url of "gid|movieId|reviewerId"
        let gid = normalizedGroupId(groupId)
        let raw = gid + "|" + movieId.uuidString + "|" + reviewerId.uuidString.lowercased()
        let data = raw.data(using: .utf8) ?? Data()
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "+", with: "-")
        b64 = b64.replacingOccurrences(of: "/", with: "_")
        b64 = b64.replacingOccurrences(of: "=", with: "")
        return CKRecord.ID(recordName: b64)
    }

    // MARK: - Save / Delete

    func saveRating(_ rating: Rating, movieId: UUID, groupId: String?) async throws {
        let route = routedDatabase(forGroupId: groupId)
        let reviewerId = stableReviewerId(for: rating, groupId: groupId)

        let baseID = recordID(groupId: groupId, movieId: movieId, reviewerId: reviewerId)
        let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID

        func applyFields(on record: CKRecord) throws -> CKRecord {
            var ratingToEncode = rating
            if ratingToEncode.reviewerId == nil {
                ratingToEncode.reviewerId = reviewerId
            }

            let data = try JSONEncoder().encode(ratingToEncode)
            record[payloadKey] = data as CKRecordValue
            record[movieIdKey] = movieId.uuidString as CKRecordValue
            record[groupIdKey] = (groupId?.isEmpty == false) ? (groupId! as CKRecordValue) : nil
            record[reviewerIdKey] = reviewerId.uuidString.lowercased() as CKRecordValue
            record[reviewerNameKey] = ratingToEncode.reviewerName as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let base: CKRecord
            do {
                base = try await route.db.record(for: id)
            } catch {
                base = CKRecord(recordType: recordType, recordID: id)
            }

            let recordToSave = try applyFields(on: base)
            _ = try await route.db.save(recordToSave)

        } catch {
            // Konflikte sind selten (ein Record pro Reviewer), aber wir behandeln sie robust.
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                let updated = try applyFields(on: serverRecord)
                _ = try await route.db.save(updated)
                return
            }
            throw error
        }
    }

    func deleteRating(movieId: UUID, groupId: String?, reviewerId: UUID) async throws {
        let route = routedDatabase(forGroupId: groupId)
        let baseID = recordID(groupId: groupId, movieId: movieId, reviewerId: reviewerId)
        let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
        _ = try await route.db.deleteRecord(withID: id)
    }

    // MARK: - Fetch

    /// Lädt alle Ratings für eine Gruppe (und optional gefiltert auf Movie-IDs).
    /// Rückgabe: [movieUUID: [Rating]]
    func fetchRatings(forGroupId groupId: String?, movieIds: [UUID]? = nil) async throws -> [UUID: [Rating]] {
        let route = routedDatabase(forGroupId: groupId)

        let predicate: NSPredicate
        if let gid = groupId, !gid.isEmpty {
            predicate = NSPredicate(format: "%K == %@", groupIdKey, gid)
        } else {
            // "Keine Gruppe": alte/default Daten – wir akzeptieren alle ohne groupId Feld
            predicate = NSPredicate(format: "%K == NULL", groupIdKey)
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
                NSPredicate(format: "%K IN %@", movieIdKey, Array(chunk))
            ])

            let records = try await fetchRecords(database: database, zoneID: zoneID, predicate: chunkPredicate)
            let decoded = try decode(records: records, groupId: groupId)
            merged = merge(dictA: merged, dictB: decoded)

            start = end
        }

        return merged
    }

    private func fetchRecords(database: CKDatabase, zoneID: CKRecordZone.ID?, predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: updatedAtKey, ascending: false)]
        return try await queryAllRecords(database: database, query: query, zoneID: zoneID)
    }

    private func decode(records: [CKRecord], groupId: String?) throws -> [UUID: [Rating]] {
        var dict: [UUID: [Rating]] = [:]

        for record in records {
            guard
                let movieIdString = record[movieIdKey] as? String,
                let uuid = UUID(uuidString: movieIdString),
                let data = record[payloadKey] as? Data
            else { continue }

            var rating = try JSONDecoder().decode(Rating.self, from: data)

            // Backfill reviewerId if missing in payload (legacy records)
            if rating.reviewerId == nil {
                if let ridString = record[reviewerIdKey] as? String,
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

    private func reviewerKey(_ r: Rating) -> String {
        if let id = r.reviewerId { return id.uuidString.lowercased() }
        return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func uniqByReviewer(_ ratings: [Rating]) -> [Rating] {
        var result: [Rating] = []
        var seen: Set<String> = []

        for r in ratings {
            let key = reviewerKey(r)
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(r)
        }
        return result
    }

    private func merge(dictA: [UUID: [Rating]], dictB: [UUID: [Rating]]) -> [UUID: [Rating]] {
        var merged = dictA
        for (movieId, ratings) in dictB {
            merged[movieId] = mergeRatings(existing: merged[movieId] ?? [], incoming: ratings)
        }
        return merged
    }

    private func mergeRatings(existing: [Rating], incoming: [Rating]) -> [Rating] {
        var out = existing
        for r in incoming {
            let key = reviewerKey(r)
            if let idx = out.firstIndex(where: { reviewerKey($0) == key }) {
                out[idx] = r
            } else {
                out.append(r)
            }
        }
        return out
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
