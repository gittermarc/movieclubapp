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
    
    private let recordType = "Movie"          // Record-Typ in CloudKit
    private let payloadKey = "payload"        // Data (codierter Movie)
    private let isBacklogKey = "isBacklog"    // Bool
    private let updatedAtKey = "updatedAt"    // Date
    
    
    init(container: CKContainer = .default()) {
        self.container = container
    }
    
    // MARK: - Laden
    
    /// Holt alle Movie-Records aus der privaten Datenbank.
    func fetchAllMovies() async throws -> [CloudMovieEntry] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        var entries: [CloudMovieEntry] = []
        
        // Neue async-API: liefert ein Dictionary mit Match-Resultaten zurück
        let (matchResults, _) = try await database.records(matching: query)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                if let entry = try decodeMovie(from: record) {
                    entries.append(entry)
                }
            case .failure(let error):
                // Für's erste nur ausgeben – später kann man das feiner behandeln
                print("CloudKit fetch error for record: \(error)")
            }
        }
        
        return entries
    }
    
    // MARK: - Speichern (Upsert)
    
    /// Speichert einen Film in CloudKit (neu oder Update).
    func save(movie: Movie, isBacklog: Bool) async throws {
        let recordID = CKRecord.ID(recordName: movie.id.uuidString)
        
        // Hilfsfunktion: unsere Daten in den Record schreiben
        func applyFields(on record: CKRecord) throws -> CKRecord {
            let data = try JSONEncoder().encode(movie)
            record[payloadKey]   = data as CKRecordValue
            record[isBacklogKey] = isBacklog as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
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
                    // Wenn hier *nochmal* ein serverRecordChanged kommt,
                    // ignorieren wir das – Server-Version gewinnt.
                    if let second = error as? CKError,
                       second.code == .serverRecordChanged {
                        return
                    } else {
                        throw error
                    }
                }
                return
            }
            
            // andere Fehler normal weitergeben
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
        
        let decoded = try JSONDecoder().decode(Movie.self, from: data)
        let isBacklog = (record[isBacklogKey] as? Bool) ?? false
        
        return CloudMovieEntry(movie: decoded, isBacklog: isBacklog)
    }
}
