//
//  CloudKitUserStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 30.12.25.
//

import Foundation
import CryptoKit
import CloudKit

/// CloudKit-Store für Gruppen-Mitglieder.
///
/// Wir speichern *ein Record pro Mitglied*, damit Deletes/Changes sauber synchronisieren.
///
/// RecordType: "GroupMember"
/// Felder:
/// - groupId   (String)
/// - memberId  (String, UUID)
/// - name      (String)
/// - avatarVersion (String, optional)
/// - avatarAsset (CKAsset, optional)
/// - updatedAt (Date)
///
/// Neuer RecordName: "<groupId>|<memberId>"
///
/// Legacy (alt): RecordName "<groupId>|<canonicalName>" ohne memberId Feld.
/// Beim Fetch migrieren wir best-effort: missing memberId wird deterministisch gesetzt.
struct CloudKitUserStore {

    struct CloudMember: Identifiable, Hashable {
        let id: UUID
        var name: String
        var avatarVersion: String?
        var avatarData: Data?

        init(
            id: UUID,
            name: String,
            avatarVersion: String? = nil,
            avatarData: Data? = nil
        ) {
            self.id = id
            self.name = name
            self.avatarVersion = avatarVersion
            self.avatarData = avatarData
        }
    }

    private let container: CKContainer

    private func routedDatabase(forGroupId groupId: String) throws -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        try CloudKitRouting.route(container: container, groupId: groupId)
    }

    private let recordType = "GroupMember"
    private let groupIdKey = "groupId"
    private let memberIdKey = "memberId"
    private let nameKey = "name"
    private let avatarVersionKey = "avatarVersion"
    private let avatarAssetKey = "avatarAsset"
    private let updatedAtKey = "updatedAt"

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Canonical helpers

    static func canonicalName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func recordIDNew(groupId: String, memberId: UUID, zoneID: CKRecordZone.ID?) -> CKRecord.ID {
        let recordName = groupId + "|" + memberId.uuidString.lowercased()
        if let zoneID { return CKRecord.ID(recordName: recordName, zoneID: zoneID) }
        return CKRecord.ID(recordName: recordName)
    }

    private func avatarVersion(from record: CKRecord) -> String? {
        let value = (record[avatarVersionKey] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    private func avatarData(from record: CKRecord) -> Data? {
        guard let asset = record[avatarAssetKey] as? CKAsset,
              let url = asset.fileURL else {
            return nil
        }

        return try? Data(contentsOf: url)
    }

    private func makeTemporaryAvatarAssetURL(for data: Data?) throws -> URL? {
        guard let data, data.isEmpty == false else { return nil }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmfreaks-member-avatar-" + UUID().uuidString.lowercased())
            .appendingPathExtension("jpg")
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func removeTemporaryAvatarAsset(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func applyFields(
        on record: CKRecord,
        member: CloudMember,
        groupId: String,
        route: (db: CKDatabase, zoneID: CKRecordZone.ID?),
        avatarAssetURL: URL?,
        clearsAvatar: Bool
    ) -> CKRecord {
        let trimmedName = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        record[groupIdKey] = groupId as CKRecordValue
        record[memberIdKey] = member.id.uuidString.lowercased() as CKRecordValue
        record[nameKey] = trimmedName as CKRecordValue
        record[updatedAtKey] = Date() as CKRecordValue

        if let avatarVersion = member.avatarVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
           avatarVersion.isEmpty == false {
            record[avatarVersionKey] = avatarVersion as CKRecordValue
            if let avatarAssetURL {
                record[avatarAssetKey] = CKAsset(fileURL: avatarAssetURL)
            }
        } else if clearsAvatar {
            record[avatarVersionKey] = nil
            record[avatarAssetKey] = nil
        }

        if let zoneID = route.zoneID {
            let rootID = CKRecord.ID(recordName: groupId, zoneID: zoneID)
            record.parent = CKRecord.Reference(recordID: rootID, action: .none)
        } else {
            record.parent = nil
        }

        return record
    }

    // MARK: - Fetch

    func fetchMembers(forGroupId groupId: String) async throws -> [CloudMember] {
        let route = try routedDatabase(forGroupId: groupId)
        let predicate = NSPredicate(format: "%K == %@", groupIdKey, groupId)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        let records: [CKRecord]
        if let zoneID = route.zoneID {
            records = try await queryAllRecords(database: route.db, query: query, zoneID: zoneID)
        } else {
            records = try await queryAllRecords(database: route.db, query: query, zoneID: nil)
        }

        var out: [CloudMember] = []
        out.reserveCapacity(records.count)

        // Best-effort migration: add memberId field if missing.
        for record in records {
            let rawName = (record[nameKey] as? String) ?? ""
            let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty { continue }

            let memberId: UUID
            if let memberIdString = record[memberIdKey] as? String,
               let parsed = UUID(uuidString: memberIdString) {
                memberId = parsed
            } else {
                // Legacy: deterministic id based on (legacy groupId, name)
                memberId = StableID.deterministicUUID(forName: trimmedName, groupId: groupId)

                // Try to write memberId back into the existing record (same recordID).
                // This avoids duplicates and makes the migration effectively "in place".
                do {
                    record[memberIdKey] = memberId.uuidString.lowercased() as CKRecordValue
                    record[updatedAtKey] = Date() as CKRecordValue
                    _ = try await route.db.save(record)
                } catch {
                    // Not fatal; we still return the derived memberId.
                    // (In shared zones, permissions may prevent writes.)
                    print("CloudKitUserStore migration: could not set memberId on legacy record: \(error)")
                }
            }

            out.append(
                .init(
                    id: memberId,
                    name: trimmedName,
                    avatarVersion: avatarVersion(from: record),
                    avatarData: avatarData(from: record)
                )
            )
        }

        // Dedupe by memberId and stable sort
        var byId: [UUID: CloudMember] = [:]
        for m in out {
            byId[m.id] = m
        }
        let unique = Array(byId.values)
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Upsert

    // MARK: - Phase 2: Batched Upserts (Migration / Initial Upload)

    /// Upsert vieler Members in Batches (CKModifyRecordsOperation).
    ///
    /// - Note: In Shared Zones kann es passieren, dass ein Client nicht in die Zone schreiben darf;
    ///   dann wirft die Operation einen Fehler. Migration nutzt i.d.R. den Owner -> ok.
    func upsertMembersBatch(
        _ members: [CloudMember],
        groupId: String
    ) async throws {
        guard !members.isEmpty else { return }

        let route = try routedDatabase(forGroupId: groupId)
        let maxPerOp = 200
        var start = 0

        while start < members.count {
            let end = min(members.count, start + maxPerOp)
            let slice = Array(members[start..<end])

            var records: [CKRecord] = []
            records.reserveCapacity(slice.count)
            var temporaryAvatarAssetURLs: [URL] = []

            defer {
                for url in temporaryAvatarAssetURLs {
                    removeTemporaryAvatarAsset(at: url)
                }
            }

            for m in slice {
                let trimmed = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                let id = recordIDNew(groupId: groupId, memberId: m.id, zoneID: route.zoneID)
                let record = CKRecord(recordType: recordType, recordID: id)
                let avatarAssetURL = try makeTemporaryAvatarAssetURL(for: m.avatarData)
                if let avatarAssetURL {
                    temporaryAvatarAssetURLs.append(avatarAssetURL)
                }

                records.append(
                    applyFields(
                        on: record,
                        member: m,
                        groupId: groupId,
                        route: route,
                        avatarAssetURL: avatarAssetURL,
                        clearsAvatar: m.avatarVersion == nil
                    )
                )
            }

            if !records.isEmpty {
                try await modifyRecords(database: route.db, saving: records, deleting: [])
            }

            start = end
        }
    }

    func upsertMember(id: UUID, name: String, groupId: String) async throws {
        try await upsertMember(
            id: id,
            name: name,
            avatarVersion: nil,
            avatarData: nil,
            clearsAvatar: false,
            groupId: groupId
        )
    }

    func upsertMember(
        id: UUID,
        name: String,
        avatarVersion: String?,
        avatarData: Data?,
        clearsAvatar: Bool = true,
        groupId: String
    ) async throws {
        let route = try routedDatabase(forGroupId: groupId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let member = CloudMember(
            id: id,
            name: trimmed,
            avatarVersion: avatarVersion,
            avatarData: avatarData
        )
        let avatarAssetURL = try makeTemporaryAvatarAssetURL(for: avatarData)
        defer { removeTemporaryAvatarAsset(at: avatarAssetURL) }

        // 1) Fast path: try new recordID
        let newID = recordIDNew(groupId: groupId, memberId: id, zoneID: route.zoneID)
        do {
            let base: CKRecord
            do {
                base = try await route.db.record(for: newID)
            } catch {
                // 2) Fallback: find existing legacy record by memberId field
                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "%K == %@", groupIdKey, groupId),
                    NSPredicate(format: "%K == %@", memberIdKey, id.uuidString.lowercased())
                ])
                let query = CKQuery(recordType: recordType, predicate: predicate)
                let found = try await queryAllRecords(database: route.db, query: query, zoneID: route.zoneID)
                if let existing = found.first {
                    base = existing
                } else {
                    base = CKRecord(recordType: recordType, recordID: newID)
                }
            }
            _ = try await route.db.save(
                applyFields(
                    on: base,
                    member: member,
                    groupId: groupId,
                    route: route,
                    avatarAssetURL: avatarAssetURL,
                    clearsAvatar: clearsAvatar
                )
            )
        } catch {
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                _ = try await route.db.save(
                    applyFields(
                        on: serverRecord,
                        member: member,
                        groupId: groupId,
                        route: route,
                        avatarAssetURL: avatarAssetURL,
                        clearsAvatar: clearsAvatar
                    )
                )
                return
            }
            throw error
        }
    }

    // MARK: - Delete

    func deleteMember(id: UUID, groupId: String) async throws {
        let route = try routedDatabase(forGroupId: groupId)
        let newID = recordIDNew(groupId: groupId, memberId: id, zoneID: route.zoneID)

        do {
            _ = try await route.db.deleteRecord(withID: newID)
            return
        } catch {
            // Fallback: delete by query (legacy recordID)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "%K == %@", groupIdKey, groupId),
                NSPredicate(format: "%K == %@", memberIdKey, id.uuidString.lowercased())
            ])
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let records = try await queryAllRecords(database: route.db, query: query, zoneID: route.zoneID)
            for r in records {
                _ = try await route.db.deleteRecord(withID: r.recordID)
            }
        }
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

// MARK: - CloudKit async helper (completion -> async)

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


// MARK: - Stable ID helper (legacy migration)

enum StableID {

    static func canonical(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Deterministic UUID derived from (groupId, name). Used for legacy migration.
    static func deterministicUUID(forName name: String, groupId: String) -> UUID {
        let seed = canonical(groupId) + "|" + canonical(name)
        let hash = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(hash)

        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )

        return UUID(uuid: uuidBytes)
    }
}
