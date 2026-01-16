//
//  CloudKitRatingStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

/// CloudKit Store für per-User Ratings (Version B).
/// Jeder User ist Creator seines Rating-Records → darf ihn auch aktualisieren.
/// Andere User können die Ratings lesen (Public DB / Schema-Rollen).
struct CloudKitRatingStore {

    // MARK: - CloudKit Setup

    private let container: CKContainer

    /// Public Database, damit alle Gruppenmitglieder Ratings lesen können.
    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Schema

    private let recordType = "MovieRating"
    private let payloadKey = "payload"          // Data: codierter Rating
    private let movieIdKey = "movieId"          // String: UUID
    private let groupIdKey = "groupId"          // String: Invite-Code
    private let reviewerNameKey = "reviewerName"// String: Name (für Debug/Query)
    private let updatedAtKey = "updatedAt"      // Date

    // MARK: - Helpers

    private func recordID(groupId: String?, movieId: UUID, reviewerName: String) -> CKRecord.ID {
        // Stabil & safe: base64-url of "gid|movieId|reviewer"
        let gid = (groupId?.isEmpty == false) ? groupId! : "nogroup"
        let raw = "\(gid)|\(movieId.uuidString)|\(reviewerName.lowercased())"
        let data = raw.data(using: .utf8) ?? Data()
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "+", with: "-")
        b64 = b64.replacingOccurrences(of: "/", with: "_")
        b64 = b64.replacingOccurrences(of: "=", with: "")
        return CKRecord.ID(recordName: b64)
    }

    // MARK: - Save / Delete

    func saveRating(_ rating: Rating, movieId: UUID, groupId: String?) async throws {
        let id = recordID(groupId: groupId, movieId: movieId, reviewerName: rating.reviewerName)

        func applyFields(on record: CKRecord) throws -> CKRecord {
            let data = try JSONEncoder().encode(rating)
            record[payloadKey] = data as CKRecordValue
            record[movieIdKey] = movieId.uuidString as CKRecordValue
            if let gid = groupId, !gid.isEmpty {
                record[groupIdKey] = gid as CKRecordValue
            } else {
                record[groupIdKey] = nil
            }
            record[reviewerNameKey] = rating.reviewerName as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let base: CKRecord
            do {
                base = try await database.record(for: id)
            } catch {
                base = CKRecord(recordType: recordType, recordID: id)
            }

            let recordToSave = try applyFields(on: base)
            _ = try await database.save(recordToSave)

        } catch {
            // Konflikte sind hier selten (ein Record pro User), aber wir behandeln sie robust.
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                let updated = try applyFields(on: serverRecord)
                _ = try await database.save(updated)
                return
            }
            throw error
        }
    }

    func deleteRating(movieId: UUID, groupId: String?, reviewerName: String) async throws {
        let id = recordID(groupId: groupId, movieId: movieId, reviewerName: reviewerName)
        _ = try await database.deleteRecord(withID: id)
    }

    // MARK: - Fetch

    /// Lädt alle Ratings für eine Gruppe (und optional gefiltert auf Movie-IDs).
    /// Rückgabe: [movieUUID: [Rating]]
    func fetchRatings(forGroupId groupId: String?, movieIds: [UUID]? = nil) async throws -> [UUID: [Rating]] {
        var predicate: NSPredicate

        if let gid = groupId, !gid.isEmpty {
            predicate = NSPredicate(format: "%K == %@", groupIdKey, gid)
        } else {
            // "Keine Gruppe": alte/default Daten – wir akzeptieren alle ohne groupId Feld
            predicate = NSPredicate(format: "%K == NULL", groupIdKey)
        }

        // Optional zusätzlich auf Movie-IDs filtern (in Chunks, weil IN-Listen begrenzt sein können)
        if let movieIds, !movieIds.isEmpty {
            let all = try await fetchRatingsChunked(groupPredicate: predicate, movieIds: movieIds)
            return all
        } else {
            let records = try await fetchRecords(predicate: predicate)
            return try decode(records: records)
        }
    }

    private func fetchRatingsChunked(groupPredicate: NSPredicate, movieIds: [UUID]) async throws -> [UUID: [Rating]] {
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

            let records = try await fetchRecords(predicate: chunkPredicate)
            let decoded = try decode(records: records)
            merged = merge(dictA: merged, dictB: decoded)

            start = end
        }

        return merged
    }

    private func fetchRecords(predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: updatedAtKey, ascending: false)]

        var collected: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            // Dein SDK liefert hier ein Array von Tupeln + Cursor zurück (siehe CloudKitMovieStore).
            let result: ([(CKRecord.ID, Result<CKRecord, any Error>)], CKQueryOperation.Cursor?)

            if let c = cursor {
                result = try await database.records(continuingMatchFrom: c)
            } else {
                result = try await database.records(matching: query)
            }

            let (matchResults, newCursor) = result
            cursor = newCursor

            for (_, recordResult) in matchResults {
                switch recordResult {
                case .success(let record):
                    collected.append(record)
                case .failure(let error):
                    print("CloudKit rating fetch error for record: \(error)")
                }
            }
        } while cursor != nil

        return collected
    }

    private func decode(records: [CKRecord]) throws -> [UUID: [Rating]] {
        var dict: [UUID: [Rating]] = [:]

        for record in records {
            guard
                let movieIdString = record[movieIdKey] as? String,
                let uuid = UUID(uuidString: movieIdString),
                let data = record[payloadKey] as? Data
            else { continue }

            let rating = try JSONDecoder().decode(Rating.self, from: data)
            dict[uuid, default: []].append(rating)
        }

        // Stabil: pro Movie nach Reviewer uniq (falls Duplikate existieren)
        for (k, list) in dict {
            dict[k] = uniqByReviewer(list)
        }

        return dict
    }

    private func uniqByReviewer(_ ratings: [Rating]) -> [Rating] {
        var result: [Rating] = []
        var seen: Set<String> = []

        for r in ratings {
            let key = r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
            if let idx = out.firstIndex(where: { $0.reviewerName.lowercased() == r.reviewerName.lowercased() }) {
                out[idx] = r
            } else {
                out.append(r)
            }
        }
        return out
    }
}
