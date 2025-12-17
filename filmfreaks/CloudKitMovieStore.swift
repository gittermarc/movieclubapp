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
        
        let predicate: NSPredicate
        
        if let groupId {
            // Nur Filme für diese Group-ID
            predicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)
        } else {
            // Alte / lokale Gruppe ohne Group-ID:
            // Records, bei denen das Feld nicht gesetzt ist bzw. nil ist
            predicate = NSPredicate(format: "%K == nil", groupIdKey)
        }
        
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        var entries: [CloudMovieEntry] = []
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
                    if let entry = try decodeMovie(from: record) {
                        entries.append(entry)
                    }
                case .failure(let error):
                    print("CloudKit fetch error for record: \(error)")
                }
            }
        } while cursor != nil
        
        return entries
    }

    
    // MARK: - Speichern (Upsert)
    
    /// Speichert einen Film in CloudKit (neu oder Update).
    func save(movie: Movie, isBacklog: Bool) async throws {
        let recordID = CKRecord.ID(recordName: movie.id.uuidString)
        
        func applyFields(on record: CKRecord) throws -> CKRecord {
            let data = try JSONEncoder().encode(movie)
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
        let isBacklog = (record[isBacklogKey] as? Bool) ?? false
        
        // Defensive: groupId im Model ggf. aus Feld nachziehen
        if let gid = record[groupIdKey] as? String, !gid.isEmpty {
            decoded.groupId = gid
        }
        
        return CloudMovieEntry(movie: decoded, isBacklog: isBacklog)
    }
}
