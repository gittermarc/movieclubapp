//
//  CloudKitGoalStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.12.25.
//
//  Step 3+4: Custom Goals werden als versioniertes Payload pro Gruppe gespeichert,
//  damit neue Goal-Typen (Director/Genre/Keyword/...) ohne Schema-Umbau dazukommen.
//

import Foundation
import CloudKit

final class CloudKitGoalStore {

    static let shared = CloudKitGoalStore()

    private let container: CKContainer
    private var database: CKDatabase { container.publicCloudDatabase }

    // Yearly goals
    private let viewingGoalRecordType = "ViewingGoal"
    private let groupIdKey = "groupId"
    private let yearKey = "year"
    private let targetKey = "target"
    private let updatedAtKey = "updatedAt"

    // Custom goals payload (one record per group)
    private let customGoalsRecordType = "ViewingCustomGoals"
    private let payloadKey = "payload"

    private init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Yearly goals

    func fetchGoals(forGroupId groupId: String?) async throws -> [Int: Int] {
        let groupValue = groupId ?? ""

        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupValue)
        let query = CKQuery(recordType: viewingGoalRecordType, predicate: predicate)

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

            cursor = page.queryCursor

            for (_, recordResult) in page.matchResults {
                switch recordResult {
                case .success(let record):
                    let year = record[yearKey] as? Int ?? 0
                    let target = record[targetKey] as? Int ?? 0
                    if year > 0 && target > 0 {
                        goals[year] = target
                    }
                case .failure(let error):
                    print("CloudKitGoalStore fetchGoals error: \(error)")
                }
            }
        } while cursor != nil

        return goals
    }

    func saveGoal(year: Int, target: Int, groupId: String?) async throws {
        let groupValue = groupId ?? ""
        let recordName = "goal_\(groupValue)_\(year)"
        let recordID = CKRecord.ID(recordName: recordName)

        func applyFields(on record: CKRecord) -> CKRecord {
            record[groupIdKey] = groupValue as CKRecordValue
            record[yearKey] = year as CKRecordValue
            record[targetKey] = target as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let baseRecord: CKRecord
            do {
                baseRecord = try await database.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: viewingGoalRecordType, recordID: recordID)
            }

            let recordToSave = applyFields(on: baseRecord)
            _ = try await database.save(recordToSave)

        } catch {
            throw error
        }
    }

    // MARK: - Custom Goals (Payload)

    private func customGoalsRecordID(for groupId: String?) -> CKRecord.ID {
        let groupValue = groupId ?? ""
        let suffix = groupValue.isEmpty ? "default" : groupValue
        return CKRecord.ID(recordName: "customGoals_\(suffix)")
    }

    func fetchCustomGoals(forGroupId groupId: String?) async throws -> ViewingCustomGoalsPayload {
        let recordID = customGoalsRecordID(for: groupId)

        do {
            let record = try await database.record(for: recordID)
            if let data = record[payloadKey] as? Data {
                do {
                    return try JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data)
                } catch {
                    // Falls Payload defekt, lieber „leer“ statt Crash
                    return ViewingCustomGoalsPayload(version: 3, goals: [])
                }
            }
            return ViewingCustomGoalsPayload(version: 3, goals: [])

        } catch {
            // Record existiert nicht → leer
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return ViewingCustomGoalsPayload(version: 3, goals: [])
            }
            throw error
        }
    }

    func saveCustomGoals(_ payload: ViewingCustomGoalsPayload, groupId: String?) async throws {
        let recordID = customGoalsRecordID(for: groupId)

        func applyFields(on record: CKRecord) throws -> CKRecord {
            record[groupIdKey] = (groupId ?? "") as CKRecordValue
            record[payloadKey] = try JSONEncoder().encode(payload) as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let baseRecord: CKRecord
            do {
                baseRecord = try await database.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: customGoalsRecordType, recordID: recordID)
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
                    if let second = error as? CKError, second.code == .serverRecordChanged {
                        // Server-Version gewinnt – akzeptieren
                        return
                    }
                    throw error
                }
                return
            }

            throw error
        }
    }

    // MARK: - Backwards-Compatible Convenience APIs (Decade/Actor)

    func fetchDecadeGoals(forGroupId groupId: String?) async throws -> [DecadeGoal] {
        let payload = try await fetchCustomGoals(forGroupId: groupId)
        return payload.goals.compactMap { $0.toDecadeGoal() }
    }

    func saveDecadeGoals(_ goals: [DecadeGoal], groupId: String?) async throws {
        var payload = try await fetchCustomGoals(forGroupId: groupId)
        payload.goals.removeAll { $0.type == .decade }
        payload.goals.append(contentsOf: goals.map { ViewingCustomGoal(from: $0) })
        payload.goals = stableDedupe(payload.goals)
        try await saveCustomGoals(payload, groupId: groupId)
    }

    func fetchActorGoals(forGroupId groupId: String?) async throws -> [ActorGoal] {
        let payload = try await fetchCustomGoals(forGroupId: groupId)
        return payload.goals.compactMap { $0.toActorGoal() }
    }

    func saveActorGoals(_ goals: [ActorGoal], groupId: String?) async throws {
        var payload = try await fetchCustomGoals(forGroupId: groupId)
        payload.goals.removeAll { $0.type == .person }
        payload.goals.append(contentsOf: goals.map { ViewingCustomGoal(from: $0) })
        payload.goals = stableDedupe(payload.goals)
        try await saveCustomGoals(payload, groupId: groupId)
    }

    private func stableDedupe(_ goals: [ViewingCustomGoal]) -> [ViewingCustomGoal] {
        var seen: Set<String> = []
        var out: [ViewingCustomGoal] = []
        out.reserveCapacity(goals.count)

        for g in goals.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let key = g.uniqueKey {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            out.append(g)
        }
        return out
    }
}
