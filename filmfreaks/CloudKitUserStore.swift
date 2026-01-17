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
    private func routedDatabase(forGroupId groupId: String) -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        guard let ctx = GroupContextStore.context(forGroupId: groupId) else {
            return (container.publicCloudDatabase, nil)
        }
        let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
        let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
        return (db, zoneID)
    }

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

    private func recordID(groupId: String, name: String, zoneID: CKRecordZone.ID?) -> CKRecord.ID {
        let canonical = Self.canonicalName(name)
        let recordName = "\(groupId)|\(canonical)"
        if let zoneID { return CKRecord.ID(recordName: recordName, zoneID: zoneID) }
        return CKRecord.ID(recordName: recordName)
    }

    // MARK: - Fetch

    func fetchMembers(forGroupId groupId: String) async throws -> [String] {
        let route = routedDatabase(forGroupId: groupId)
        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        let records: [CKRecord]
        if let zoneID = route.zoneID {
            records = try await queryAllRecords(database: route.db, query: query, zoneID: zoneID)
        } else {
            records = try await queryAllRecords(database: route.db, query: query, zoneID: nil)
        }

        var names: [String] = []
        names.reserveCapacity(records.count)
        for record in records {
            if let name = record[nameKey] as? String {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { names.append(trimmed) }
            }
        }

        // Dedupe + stable sort
        let unique = Array(Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
        return unique.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Upsert

    func upsertMember(name: String, groupId: String) async throws {
        let route = routedDatabase(forGroupId: groupId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let recordID = recordID(groupId: groupId, name: trimmed, zoneID: route.zoneID)

        func applyFields(on record: CKRecord) -> CKRecord {
            record[groupIdKey] = groupId as CKRecordValue
            record[nameKey] = trimmed as CKRecordValue
            record[updatedAtKey] = Date() as CKRecordValue
            return record
        }

        do {
            let baseRecord: CKRecord
            do {
                baseRecord = try await route.db.record(for: recordID)
            } catch {
                baseRecord = CKRecord(recordType: recordType, recordID: recordID)
            }
            _ = try await route.db.save(applyFields(on: baseRecord))
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                // Server-Version als Basis nehmen – wir wollen zumindest sicherstellen,
                // dass groupId/name korrekt gesetzt sind.
                _ = try await route.db.save(applyFields(on: serverRecord))
                return
            }
            throw error
        }
    }

    // MARK: - Delete

    func deleteMember(name: String, groupId: String) async throws {
        let route = routedDatabase(forGroupId: groupId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let recordID = recordID(groupId: groupId, name: trimmed, zoneID: route.zoneID)
        _ = try await route.db.deleteRecord(withID: recordID)
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
