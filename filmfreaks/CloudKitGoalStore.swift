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
/// Custom Goals (Step 3 - generisch, versioniertes Payload):
/// Record-Type: "ViewingCustomGoals"
/// Felder:
/// - groupId: String
/// - payload: Data     → JSON-encoded ViewingCustomGoalsPayload (v3)
/// - updatedAt: Date
///
/// Backward-Compat:
/// - Step 1 speicherte payload als [DecadeGoal]
/// - Step 2 speicherte payload als ViewingCustomGoalsPayloadV2 (decadeGoals + actorGoals)
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

    // MARK: - Custom Goals (v3)

    private let customRecordType = "ViewingCustomGoals"
    private let payloadKey = "payload"

    private init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Laden (Jahresziele)

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

    func saveGoal(year: Int, target: Int, groupId: String?) async throws {
        let groupValue = groupId ?? ""

        let recordName = "goal-\(groupValue)-\(year)"
        let recordID = CKRecord.ID(recordName: recordName)

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

    // MARK: - Custom Goals (v3 Payload) – Laden

    func fetchCustomGoals(forGroupId groupId: String?) async throws -> ViewingCustomGoalsPayload {
        let groupValue = groupId ?? ""
        let recordID = CKRecord.ID(recordName: "custom-goals-\(groupValue)")

        do {
            let record = try await database.record(for: recordID)
            guard let data = record[payloadKey] as? Data else {
                return ViewingCustomGoalsPayload(version: 3, goals: [])
            }

            // 1) Aktuell: v3
            if let decodedV3 = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data) {
                return decodedV3
            }

            // 2) Legacy: v2 (Decade + Actor getrennt)
            if let decodedV2 = try? JSONDecoder().decode(ViewingCustomGoalsPayloadV2.self, from: data) {
                return decodedV2.toV3()
            }

            // 3) Legacy: Step 1 – payload war [DecadeGoal]
            if let legacyDecades = try? JSONDecoder().decode([DecadeGoal].self, from: data) {
                let goals = legacyDecades.map { ViewingCustomGoal(from: $0) }
                return ViewingCustomGoalsPayload(version: 3, goals: goals)
            }

            // 4) Wenn kaputt: leer zurück
            return ViewingCustomGoalsPayload(version: 3, goals: [])

        } catch let ckError as CKError {
            if ckError.code == .unknownItem {
                return ViewingCustomGoalsPayload(version: 3, goals: [])
            }
            throw ckError
        } catch {
            throw error
        }
    }

    // MARK: - Custom Goals (v3 Payload) – Speichern (Upsert)

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

    // MARK: - Backward API (falls andere Stellen noch Step-1/2-Methoden aufrufen)

    func fetchDecadeGoals(forGroupId groupId: String?) async throws -> [DecadeGoal] {
        let payload = try await fetchCustomGoals(forGroupId: groupId)
        return payload.goals.compactMap { $0.toDecadeGoal() }
    }

    func saveDecadeGoals(_ goals: [DecadeGoal], groupId: String?) async throws {
        let payload = ViewingCustomGoalsPayload(
            version: 3,
            goals: goals.map { ViewingCustomGoal(from: $0) }
        )
        try await saveCustomGoals(payload, groupId: groupId)
    }
}
