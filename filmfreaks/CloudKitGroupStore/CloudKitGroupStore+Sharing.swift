//
//  CloudKitGroupStore+Sharing.swift
//  filmfreaks
//

import Foundation
import CloudKit

private let shareHierarchyRepairKeyPrefix = "ff.ck.shareHierarchyRepair.v1."

extension CloudKitGroupStore {

    /// Creates (or updates) a CKShare for the group's root record.
    func fetchOrCreateShare(for group: GroupContext) async throws -> CKShare {
        guard group.scope == .private else {
            throw NSError(
                domain: "CloudKitGroupStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Nur Owned-Gruppen können geteilt werden."]
            )
        }

        let zoneID = CKRecordZone.ID(zoneName: group.zoneName, ownerName: group.ownerName)
        let rootID = CKRecord.ID(recordName: group.id, zoneID: zoneID)
        let root = try await privateDB.record(for: rootID)

        // If the root record is already shared, CloudKit stores a reference to the share record in
        // the root's system field `share`. Fetch and reuse that share so we keep the participant list.
        if let existingShareRef = root.share {
            do {
                let fetched = try await privateDB.record(for: existingShareRef.recordID)
                if let existing = fetched as? CKShare {
                    // Keep title in sync with the current group name.
                    existing[CKShare.SystemFieldKey.title] = group.name as CKRecordValue
                    try await modifyRecords(database: privateDB, saving: [existing], deleting: [])
                    return existing
                }
            } catch {
                // Fall through to creating a new share.
            }
        }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue

        try await modifyRecords(database: privateDB, saving: [root, share], deleting: [])
        return share
    }

    // MARK: - Share hierarchy repair (record sharing)

    func repairShareHierarchyIfNeeded(for group: GroupContext) async {
        guard group.scope == .private else { return }

        let key = shareHierarchyRepairKeyPrefix + group.id
        if UserDefaults.standard.bool(forKey: key) {
            return
        }

        do {
            try await repairShareHierarchy(for: group)
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            // Don't mark as done; we'll retry next refresh.
            print("CloudKitGroupStore: share hierarchy repair failed for \(group.id): \(error)")
        }
    }

    /// Ensures that all group-related records are descendants of the group's root record.
    /// This is required for CloudKit *record sharing* so participants can see/write these records.
    func repairShareHierarchy(for group: GroupContext) async throws {
        let zoneID = CKRecordZone.ID(zoneName: group.zoneName, ownerName: group.ownerName)
        let rootID = CKRecord.ID(recordName: group.id, zoneID: zoneID)
        let rootRef = CKRecord.Reference(recordID: rootID, action: .none)

        // Keep in sync with record types used by the CloudKit stores.
        let recordTypes: [String] = [
            "Movie",
            "MovieRating",
            "GroupMember",
            "ViewingGoal",
            "ViewingCustomGoals"
        ]

        for type in recordTypes {
            let predicate = NSPredicate(format: "%K == %@", "groupId", group.id)
            let records = try await queryAllRecords(
                database: privateDB,
                recordType: type,
                predicate: predicate,
                zoneID: zoneID
            )

            let toFix = records.filter { $0.parent?.recordID != rootID }
            guard !toFix.isEmpty else { continue }

            for record in toFix {
                record.parent = rootRef
                // Save individually to be resilient to partial failures/conflicts.
                do {
                    _ = try await privateDB.save(record)
                } catch {
                    if let ckError = error as? CKError,
                       ckError.code == .serverRecordChanged,
                       let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                        serverRecord.parent = rootRef
                        _ = try await privateDB.save(serverRecord)
                    } else {
                        // Best-effort: keep going so one bad record doesn't block the whole repair.
                        print(
                            "CloudKitGroupStore: could not reparent \(type) record \(record.recordID.recordName): \(error)"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - CloudKit async helpers (completion -> async)

private func queryAllRecords(
    database: CKDatabase,
    recordType: String,
    predicate: NSPredicate,
    zoneID: CKRecordZone.ID
) async throws -> [CKRecord] {

    var all: [CKRecord] = []
    var cursor: CKQueryOperation.Cursor? = nil

    while true {
        let page: ([CKRecord], CKQueryOperation.Cursor?) = try await withCheckedThrowingContinuation { cont in
            let op: CKQueryOperation
            if let cursor {
                op = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: predicate)
                op = CKQueryOperation(query: query)
                op.zoneID = zoneID
            }

            var pageRecords: [CKRecord] = []
            op.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    pageRecords.append(record)
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    cont.resume(returning: (pageRecords, nextCursor))
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }

            database.add(op)
        }

        all.append(contentsOf: page.0)
        cursor = page.1

        if cursor == nil {
            break
        }
    }

    return all
}

private func modifyRecords(database: CKDatabase, saving: [CKRecord], deleting: [CKRecord.ID]) async throws {
    try await withCheckedThrowingContinuation { cont in
        let op = CKModifyRecordsOperation(recordsToSave: saving, recordIDsToDelete: deleting)
        op.savePolicy = .changedKeys
        op.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                cont.resume(returning: ())
            case .failure(let error):
                cont.resume(throwing: error)
            }
        }
        database.add(op)
    }
}
