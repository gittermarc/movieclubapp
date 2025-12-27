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
///
/// Custom Goals (Decade + Actor, versioniertes Payload):
/// Record-Type: "ViewingCustomGoals"
/// Felder:
/// - groupId: String
/// - payload: Data     → JSON-encoded ViewingCustomGoalsPayload (v2)
/// - updatedAt: Date
///
/// Backward-Compat:
/// - Step 1 speicherte payload als [DecadeGoal]
final class CloudKitGoalStore {

    static let shared = CloudKitGoalStore()

    private let container: CKContainer
    private var database: CKDatabase {
        container.publicCloudDatabase
    }

    // MARK: - Jahresziele

    private let recordType   = "ViewingGoal"
    private let groupIdKey   = "groupId"
    private let yearKey      = "year"
    private let targetKey    = "target"
    private let updatedAtKey = "updatedAt"

    // MARK: - Custom Goals (Decade + Actor)

    private let customRecordType = "ViewingCustomGoals"
    private let payloadKey = "payload"

    private init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Laden (Jahresziele)

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

    // MARK: - Speichern (Upsert) (Jahresziele)

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
            throw error
        }
    }

    // MARK: - Custom Goals (v2 Payload) – Laden

    func fetchCustomGoals(forGroupId groupId: String?) async throws -> ViewingCustomGoalsPayload {
        let groupValue = groupId ?? ""
        let recordID = CKRecord.ID(recordName: "custom-goals-\(groupValue)")

        do {
            let record = try await database.record(for: recordID)
            guard let data = record[payloadKey] as? Data else {
                return ViewingCustomGoalsPayload(version: 2, decadeGoals: [], actorGoals: [])
            }

            // 1) Neu: payload als ViewingCustomGoalsPayload
            if let decoded = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data) {
                return decoded
            }

            // 2) Backward-Compat: payload war [DecadeGoal]
            if let legacyDecades = try? JSONDecoder().decode([DecadeGoal].self, from: data) {
                return ViewingCustomGoalsPayload(version: 2, decadeGoals: legacyDecades, actorGoals: [])
            }

            // 3) Wenn kaputt: leer zurück
            return ViewingCustomGoalsPayload(version: 2, decadeGoals: [], actorGoals: [])

        } catch let ckError as CKError {
            if ckError.code == .unknownItem {
                return ViewingCustomGoalsPayload(version: 2, decadeGoals: [], actorGoals: [])
            }
            throw ckError
        } catch {
            throw error
        }
    }

    // MARK: - Custom Goals (v2 Payload) – Speichern (Upsert)

    func saveCustomGoals(_ payload: ViewingCustomGoalsPayload, groupId: String?) async throws {
        let groupValue = groupId ?? ""
        let recordID = CKRecord.ID(recordName: "custom-goals-\(groupValue)")

        func applyFields(on record: CKRecord) throws -> CKRecord {
            let data = try JSONEncoder().encode(payload)
            record[groupIdKey] = groupValue as CKRecordValue
            record[payloadKey] = data as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let baseRecord: CKRecord
            do {
                baseRecord = try await database.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: customRecordType, recordID: recordID)
            }

            let recordToSave = try applyFields(on: baseRecord)
            _ = try await database.save(recordToSave)

        } catch {
            // Konfliktbehandlung: ServerRecordChanged → Server holen, Felder anwenden, nochmal speichern
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

    // MARK: - Backward API (falls andere Stellen noch Step-1-Methoden aufrufen)

    func fetchDecadeGoals(forGroupId groupId: String?) async throws -> [DecadeGoal] {
        let payload = try await fetchCustomGoals(forGroupId: groupId)
        return payload.decadeGoals
    }

    func saveDecadeGoals(_ goals: [DecadeGoal], groupId: String?) async throws {
        var payload = try await fetchCustomGoals(forGroupId: groupId)
        payload.decadeGoals = goals
        try await saveCustomGoals(payload, groupId: groupId)
    }
}
