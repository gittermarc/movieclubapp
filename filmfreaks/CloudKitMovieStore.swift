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
    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    private let recordType   = "Movie"       // Record-Typ in CloudKit
    private let payloadKey   = "payload"     // Data (codierter Movie)
    private let isBacklogKey = "isBacklog"   // Bool
    private let updatedAtKey = "updatedAt"   // Date
    private let groupIdKey   = "groupId"     // String: aktuelle Gruppen-ID (Invite-Code) oder leer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Laden

    /// Holt alle Movie-Records für eine bestimmte Gruppe.
    ///
    /// - Parameter groupId:
    ///   - nil    → Filme ohne Gruppe (alte / lokale Standard-Gruppe)
    ///   - String → Filme mit genau dieser Group-ID (Invite-Code)
    func fetchMovies(forGroupId groupId: String?) async throws -> [CloudMovieEntry] {
        // Gruppe mit Invite-Code
        if let groupId, !groupId.isEmpty {
            // 1) Schneller Weg: nur Records mit gesetztem groupId-Feld.
            let fastPredicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)
            let fastEntries = try await fetchMovies(with: fastPredicate)
            if !fastEntries.isEmpty {
                return fastEntries
            }

            // 2) Legacy-Migration (ohne All-Records-Scan):
            //    Wir scannen *nur* Records ohne groupId-Feld (NULL/""), dekodieren das Payload
            //    und setzen anschließend groupId als eigenes Feld.
            //
            //    Dadurch verschwindet die teure "fetch all"-Logik komplett.
            return try await migrateLegacyGroupIdFieldAndFetch(forGroupId: groupId)
        }

        // „Standardgruppe“ ohne Group-ID:
        // Records, bei denen das Feld nicht gesetzt ist bzw. NULL/"" ist.
        // Wichtig: Wir filtern defensiv alle Records raus, deren Payload bereits eine groupId enthält,
        // damit Legacy-Gruppen-Records nicht in der Standardgruppe auftauchen.
        let predicate = NSPredicate(format: "%K == NULL OR %K == ''", groupIdKey, groupIdKey)
        let entries = try await fetchMovies(with: predicate)
        return entries.filter { ($0.movie.groupId?.isEmpty ?? true) }
    }

    // MARK: - Legacy Migration

    /// Legacy-Migration: Records ohne groupId-Feld (NULL/""), deren JSON-Payload aber bereits
    /// eine groupId enthält, werden "hochgezogen": groupId wird als eigenes Feld gespeichert.
    ///
    /// Wichtig: Diese Migration macht **keinen All-Records-Scan** – es werden nur Records
    /// ohne gesetztes Feld angefragt.
    private func migrateLegacyGroupIdFieldAndFetch(forGroupId groupId: String) async throws -> [CloudMovieEntry] {
        // 1) Nur Legacy-Kandidaten laden (groupId-Feld fehlt oder ist leer)
        let legacyPredicate = NSPredicate(format: "%K == NULL OR %K == ''", groupIdKey, groupIdKey)
        let legacyRecords = try await fetchRecords(with: legacyPredicate)
        if legacyRecords.isEmpty {
            return []
        }

        // 2) Payload dekodieren und nur die Records behalten, die wirklich zu dieser Gruppe gehören.
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
                // Ein kaputtes Payload soll nicht die gesamte Migration verhindern.
                print("CloudKit legacy decode error: \(error)")
            }
        }

        if candidates.isEmpty {
            return []
        }

        // 3) Best-Effort Migration: groupId-Feld setzen und speichern.
        //    Falls das Speichern fehlschlägt (z.B. Permission/Conflict), geben wir dennoch
        //    die gefundenen Entries zurück, damit die UI korrekt bleibt.
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

    /// Speichert (best-effort) das groupId-Feld auf einem bestehenden Record.
    ///
    /// Konflikte werden wie beim normalen save() aufgelöst: ServerRecord wird übernommen,
    /// aber groupId wird erneut gesetzt.
    private func saveLegacyMigration(recordID: CKRecord.ID, groupId: String) async throws {
        func applyFields(on record: CKRecord) -> CKRecord {
            record[groupIdKey] = groupId as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let base = try await database.record(for: recordID)
            let recordToSave = applyFields(on: base)
            _ = try await database.save(recordToSave)
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let updated = applyFields(on: serverRecord)
                _ = try await database.save(updated)
                return
            }
            throw error
        }
    }

    // MARK: - Query Helpers

    /// Interne Helper-Funktion, die eine Query mit Paginierung ausführt und Records sammelt.
    private func fetchRecords(with predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)

        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            // Dein SDK liefert hier ein Array von Tupeln + Cursor zurück
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
                    records.append(record)
                case .failure(let error):
                    print("CloudKit fetch error for record: \(error)")
                }
            }
        } while cursor != nil

        return records
    }

    /// Interne Helper-Funktion, die eine Query mit Paginierung ausführt und direkt zu Entries dekodiert.
    private func fetchMovies(with predicate: NSPredicate) async throws -> [CloudMovieEntry] {
        let records = try await fetchRecords(with: predicate)
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

    /// Speichert einen Film in CloudKit (neu oder Update).
    func save(movie: Movie, isBacklog: Bool) async throws {
        let recordID = CKRecord.ID(recordName: movie.id.uuidString)

        func applyFields(on record: CKRecord) throws -> CKRecord {
            var movieForCloud = movie
            movieForCloud.ratings = []
            let data = try JSONEncoder().encode(movieForCloud)
            record[payloadKey]   = data as CKRecordValue
            record[isBacklogKey] = isBacklog as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue

            // Gruppen-ID extra als Feld speichern, damit wir nach Gruppen filtern können
            if let gid = movie.groupId, !gid.isEmpty {
                record[groupIdKey] = gid as CKRecordValue
            } else {
                // Feld entfernen, falls keine Gruppe
                record[groupIdKey] = nil
            }
            return record
        }

        do {
            // Basis-Record holen (oder neu anlegen)
            let baseRecord: CKRecord
            do {
                baseRecord = try await database.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: recordType, recordID: recordID)
            }

            let recordToSave = try applyFields(on: baseRecord)
            _ = try await database.save(recordToSave)

        } catch {
            // Konflikt: Server hat inzwischen eine andere Version
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                let updatedRecord = try applyFields(on: serverRecord)

                do {
                    _ = try await database.save(updatedRecord)
                } catch {
                    if let second = error as? CKError,
                       second.code == .serverRecordChanged {
                        // Server-Version gewinnt – einfach akzeptieren
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

    // MARK: - Löschen

    /// Löscht einen Film anhand seiner Movie-ID.
    func delete(movieID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: movieID.uuidString)
        _ = try await database.deleteRecord(withID: recordID)
    }

    // MARK: - Hilfsfunktion: Record → Movie

    private func decodeMovie(from record: CKRecord) throws -> CloudMovieEntry? {
        guard let data = record[payloadKey] as? Data else {
            return nil
        }

        var decoded = try JSONDecoder().decode(Movie.self, from: data)
        // Ratings werden in Version B separat als MovieRating Records gespeichert
        decoded.ratings = []
        let isBacklog = (record[isBacklogKey] as? Bool) ?? false

        // Defensive: groupId im Model ggf. aus Feld nachziehen
        if let gid = record[groupIdKey] as? String, !gid.isEmpty {
            decoded.groupId = gid
        }

        return CloudMovieEntry(movie: decoded, isBacklog: isBacklog)
    }
}
