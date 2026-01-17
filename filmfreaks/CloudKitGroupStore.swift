//
//  CloudKitGroupStore.swift
//  filmfreaks
//
//  Creates and lists CloudKit-sharing based groups.
//

import Foundation
import CloudKit
import Combine
internal import SwiftUI

@MainActor
final class CloudKitGroupStore: ObservableObject {

    @Published private(set) var ownedGroups: [GroupContext] = []
    @Published private(set) var sharedGroups: [GroupContext] = []

    private let container: CKContainer
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    private let groupRecordType = "FFGroup"
    private let nameKey = "name"
    private let createdAtKey = "createdAt"

    init(container: CKContainer = .default()) {
        self.container = container

        // When a share is accepted, refresh the list.
        NotificationCenter.default.addObserver(
            forName: .cloudKitShareAccepted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        do {
            let owned = try await fetchGroupContexts(in: privateDB, scope: .private)
            let shared = try await fetchGroupContexts(in: sharedDB, scope: .shared)

            self.ownedGroups = owned.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.sharedGroups = shared.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Persist contexts so other stores can route by groupId.
            for g in owned + shared {
                GroupContextStore.upsert(g)
            }
        } catch {
            print("CloudKitGroupStore.refresh error: \(error)")
        }
    }

    func createGroup(name: String) async throws -> GroupContext {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupId = UUID().uuidString
        let zoneName = "group.\(groupId)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // Create zone (idempotent).
        _ = try await createZoneIfNeeded(zoneID: zoneID)

        let recordID = CKRecord.ID(recordName: groupId, zoneID: zoneID)
        let record = CKRecord(recordType: groupRecordType, recordID: recordID)
        record[nameKey] = trimmed as CKRecordValue
        record[createdAtKey] = Date() as CKRecordValue
        _ = try await privateDB.save(record)

        let ctx = GroupContext(id: groupId, name: trimmed, scope: .private, zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        GroupContextStore.upsert(ctx)

        await refresh()
        return ctx
    }

    /// Creates (or updates) a CKShare for the group's root record.
    func fetchOrCreateShare(for group: GroupContext) async throws -> CKShare {
        guard group.scope == .private else {
            throw NSError(domain: "CloudKitGroupStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nur Owned-Gruppen können geteilt werden."])
        }

        let zoneID = CKRecordZone.ID(zoneName: group.zoneName, ownerName: group.ownerName)
        let rootID = CKRecord.ID(recordName: group.id, zoneID: zoneID)
        let root = try await privateDB.record(for: rootID)

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = group.name as CKRecordValue

        try await modifyRecords(database: privateDB, saving: [root, share], deleting: [])
        return share
    }

    // MARK: - Private helpers

    /// IMPORTANT:
    /// We intentionally DO NOT query for FFGroup records.
    /// Some CloudKit environments throw "recordName is not queryable" for queries.
    ///
    /// Our design guarantees:
    /// - Zone name: "group.<GROUP_ID>"
    /// - Root record name: "<GROUP_ID>" inside that zone
    ///
    /// So we list zones and directly fetch the root record by ID.
    private func fetchGroupContexts(in db: CKDatabase, scope: GroupScope) async throws -> [GroupContext] {
        let zones = try await fetchAllZones(in: db)
        let groupZones = zones.filter { $0.zoneID.zoneName.hasPrefix("group.") }

        var contexts: [GroupContext] = []
        contexts.reserveCapacity(groupZones.count)

        for zone in groupZones {
            let zoneName = zone.zoneID.zoneName
            guard let groupId = parseGroupId(fromZoneName: zoneName) else { continue }

            let rootID = CKRecord.ID(recordName: groupId, zoneID: zone.zoneID)

            do {
                let record = try await db.record(for: rootID)
                let name = (record[nameKey] as? String) ?? "Filmgruppe"
                let ownerName = record.recordID.zoneID.ownerName

                contexts.append(
                    GroupContext(
                        id: groupId,
                        name: name,
                        scope: scope,
                        zoneName: zoneName,
                        ownerName: ownerName
                    )
                )
            } catch {
                // If the zone exists but the root record was deleted or not created yet, ignore it.
                // (This can happen in edge cases during migration or partial writes.)
                print("CloudKitGroupStore: Could not fetch root record for zone \(zoneName): \(error)")
                continue
            }
        }

        return contexts
    }

    private func parseGroupId(fromZoneName zoneName: String) -> String? {
        let prefix = "group."
        guard zoneName.hasPrefix(prefix) else { return nil }
        let id = String(zoneName.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }

    private func createZoneIfNeeded(zoneID: CKRecordZone.ID) async throws -> CKRecordZone {
        do {
            let zone = CKRecordZone(zoneID: zoneID)
            return try await privateDB.save(zone)
        } catch {
            // Zone creation is idempotent for our purposes.
            return CKRecordZone(zoneID: zoneID)
        }
    }
}

// MARK: - CloudKit async helpers (completion -> async)

private func fetchAllZones(in db: CKDatabase) async throws -> [CKRecordZone] {
    try await withCheckedThrowingContinuation { cont in
        db.fetchAllRecordZones { zones, error in
            if let error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: zones ?? [])
            }
        }
    }
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
