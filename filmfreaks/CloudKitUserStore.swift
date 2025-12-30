//
//  CloudKitUserStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 30.12.25.
//

import Foundation
import CloudKit

/// CloudKit-Store für Gruppen-Mitglieder.
///
/// WICHTIG: Wir speichern *ein Record pro Mitglied* (statt „eine Liste pro Gruppe“),
/// damit Deletes/Changes sauber synchronisieren und wir keine Merge-Hölle bekommen.
///
/// RecordType: "GroupMember"
/// Felder:
/// - groupId   (String)
/// - name      (String)
/// - updatedAt (Date)
///
/// RecordName: "<groupId>|<canonicalName>"
struct CloudKitUserStore {

    private let container: CKContainer
    private var database: CKDatabase { container.publicCloudDatabase }

    private let recordType = "GroupMember"
    private let groupIdKey = "groupId"
    private let nameKey = "name"
    private let updatedAtKey = "updatedAt"

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Canonical helpers

    static func canonicalName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func recordID(groupId: String, name: String) -> CKRecord.ID {
        let canonical = Self.canonicalName(name)
        return CKRecord.ID(recordName: "\(groupId)|\(canonical)")
    }

    // MARK: - Fetch

    func fetchMembers(forGroupId groupId: String) async throws -> [String] {
        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        var names: [String] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
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
                    if let name = record[nameKey] as? String {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            names.append(trimmed)
                        }
                    }
                case .failure(let error):
                    print("CloudKitUserStore fetch error: \(error)")
                }
            }
        } while cursor != nil

        // Dedupe + stable sort
        let unique = Array(Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Upsert

    func upsertMember(name: String, groupId: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let recordID = recordID(groupId: groupId, name: trimmed)

        func applyFields(on record: CKRecord) -> CKRecord {
            record[groupIdKey] = groupId as CKRecordValue
            record[nameKey] = trimmed as CKRecordValue
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
            _ = try await database.save(applyFields(on: baseRecord))
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                // Server-Version als Basis nehmen – wir wollen zumindest sicherstellen,
                // dass groupId/name korrekt gesetzt sind.
                _ = try await database.save(applyFields(on: serverRecord))
                return
            }
            throw error
        }
    }

    // MARK: - Delete

    func deleteMember(name: String, groupId: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let recordID = recordID(groupId: groupId, name: trimmed)
        _ = try await database.deleteRecord(withID: recordID)
    }
}
