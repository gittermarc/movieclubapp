//
//  CloudKitGoalStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.12.25.
//

import Foundation
import CloudKit

/// Kapselt CloudKit-Zugriffe für Jahresziele (Viewing Goals).
///
/// Record-Type: "ViewingGoal"
/// Felder:
/// - groupId: String   → Gruppen-ID (Invite-Code) oder "" für Default-Gruppe
/// - year:    Int      → Jahr (z.B. 2025)
/// - target:  Int      → Zielanzahl Filme
/// - updatedAt: Date   → Zeitstempel für Debug/Sortierung
final class CloudKitGoalStore {
    
    static let shared = CloudKitGoalStore()
    
    private let container: CKContainer
    private var database: CKDatabase {
        container.publicCloudDatabase
    }
    
    private let recordType   = "ViewingGoal"
    private let groupIdKey   = "groupId"
    private let yearKey      = "year"
    private let targetKey    = "target"
    private let updatedAtKey = "updatedAt"
    
    private init(container: CKContainer = .default()) {
        self.container = container
    }
    
    // MARK: - Laden
    
    /// Lädt alle Ziele für eine bestimmte Gruppe aus CloudKit.
    ///
    /// - Parameter groupId:
    ///   - nil oder leer → wird als "" gespeichert und gefiltert
    func fetchGoals(forGroupId groupId: String?) async throws -> [Int: Int] {
        let groupValue = groupId ?? ""
        
        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupValue)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        var goals: [Int: Int] = [:]
        var cursor: CKQueryOperation.Cursor? = nil
        
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
                       queryCursor: CKQueryOperation.Cursor?)
            
            if let c = cursor {
                page = try await database.records(continuingMatchFrom: c)
            } else {
                page = try await database.records(matching: query)
            }
            
            for (_, recordResult) in page.matchResults {
                switch recordResult {
                case .success(let record):
                    // year & target möglichst robust lesen
                    let yearValue: Int?
                    let targetValue: Int?
                    
                    if let y = record[yearKey] as? Int {
                        yearValue = y
                    } else if let yNum = record[yearKey] as? NSNumber {
                        yearValue = yNum.intValue
                    } else {
                        yearValue = nil
                    }
                    
                    if let t = record[targetKey] as? Int {
                        targetValue = t
                    } else if let tNum = record[targetKey] as? NSNumber {
                        targetValue = tNum.intValue
                    } else {
                        targetValue = nil
                    }
                    
                    if let year = yearValue, let target = targetValue {
                        goals[year] = target
                    }
                    
                case .failure(let error):
                    print("CloudKit ViewingGoal fetch record error: \(error)")
                }
            }
            
            cursor = page.queryCursor
        } while cursor != nil
        
        return goals
    }
    
    // MARK: - Speichern (Upsert)
    
    /// Speichert (oder aktualisiert) das Ziel für ein bestimmtes Jahr in einer Gruppe.
    func saveGoal(year: Int, target: Int, groupId: String?) async throws {
        let groupValue = groupId ?? ""
        
        // Eindeutiger Record-Name: groupId + Jahr
        let recordName = "goal-\(groupValue)-\(year)"
        let recordID = CKRecord.ID(recordName: recordName)
        
        // Hilfsfunktion: Felder setzen
        func applyFields(on record: CKRecord) -> CKRecord {
            record[groupIdKey]   = groupValue as CKRecordValue
            record[yearKey]      = year as CKRecordValue
            record[targetKey]    = target as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }
        
        do {
            let baseRecord: CKRecord
            do {
                baseRecord = try await database.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: recordType, recordID: recordID)
            }
            
            let recordToSave = applyFields(on: baseRecord)
            _ = try await database.save(recordToSave)
            
        } catch {
            // Wenn du magst, kannst du hier noch serverRecordChanged behandeln
            // analog zum Movie-Store. Für Ziele reicht meist das einfache Upsert.
            throw error
        }
    }
}
