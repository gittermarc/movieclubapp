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

    private let subscriptionManager: CloudKitActivitySubscriptionManager

    private let groupRecordType = "FFGroup"
    private let nameKey = "name"
    private let createdAtKey = "createdAt"

    private var lastICloudProblemToastAt: Date?

    // MARK: - Share hierarchy repair (record sharing)

    private let shareHierarchyRepairKeyPrefix = "ff.ck.shareHierarchyRepair.v1."

    init(container: CKContainer = .default()) {
        self.container = container
        self.subscriptionManager = CloudKitActivitySubscriptionManager(container: container)

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
            // If the user is not signed into iCloud, shared/owned zones are unavailable.
            // Surface a clear message instead of silently showing an empty list.
            let status = try await fetchAccountStatus()
            if status == .noAccount || status == .restricted {
                maybeShowICloudProblemToast(status: status)
                self.ownedGroups = []
                self.sharedGroups = []
                return
            }

            let owned = try await fetchGroupContexts(in: privateDB, scope: .private)
            let shared = try await fetchGroupContexts(in: sharedDB, scope: .shared)

            self.ownedGroups = owned.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.sharedGroups = shared.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Persist contexts so other stores can route by groupId.
            for g in owned + shared {
                GroupContextStore.upsert(g)
            }

            // P1: Ensure CloudKit subscriptions exist so group activity can trigger
            // content-available pushes (we will translate those into user-visible
            // notifications in a later step).
            Task {
                await subscriptionManager.ensureSubscriptions(forOwnedGroups: owned)
                await subscriptionManager.ensureSubscriptions(forSharedGroups: shared)
            }

            // P1: Ensure CloudKit subscriptions exist so changes can wake the app via
            // content-available pushes (later -> map to local notifications).
            Task {
                await subscriptionManager.ensureSubscriptions(forOwnedGroups: owned)
                await subscriptionManager.ensureSubscriptions(forSharedGroups: shared)
            }

            // One-time repair for older builds:
            // We share the group's root record via CloudKit *record sharing*.
            // Only the root record + its descendants are visible/writable for participants.
            // Older builds stored Movies/Ratings/Goals/Members without a `parent` -> they never became
            // part of the share, so other users couldn't see them (and writes could fail).
            for g in owned {
                Task { await self.repairShareHierarchyIfNeeded(for: g) }
            }
        } catch {
            print("CloudKitGroupStore.refresh error: \(error)")
        }
    }

    private func fetchAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { cont in
            container.accountStatus { status, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: status)
                }
            }
        }
    }

    private func maybeShowICloudProblemToast(status: CKAccountStatus) {
        let now = Date()
        if let last = lastICloudProblemToastAt, now.timeIntervalSince(last) < 120 {
            return
        }
        lastICloudProblemToastAt = now

        let message: String
        switch status {
        case .noAccount:
            message = "Du bist nicht bei iCloud angemeldet. Bitte iCloud in den iOS-Einstellungen aktivieren – sonst funktionieren Cloud-Gruppen & Einladungen nicht."
        case .restricted:
            message = "iCloud ist auf diesem Gerät eingeschränkt (z. B. MDM/Bildschirmzeit). Cloud-Gruppen sind daher nicht verfügbar."
        default:
            message = "iCloud ist gerade nicht verfügbar."
        }

        ToastCenter.shared.show(
            .error(title: "iCloud erforderlich", message: message),
            autoHideAfter: 4.0
        )
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

    // MARK: - Delete / Leave

    /// Deletes an Owned group (the current user is the owner).
    /// This removes the entire record zone in the private database (including all movies/ratings/goals/members).
    func deleteOwnedGroup(_ group: GroupContext) async throws {
        guard group.scope == .private else {
            throw NSError(domain: "CloudKitGroupStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Nur Owned-Gruppen können gelöscht werden."])
        }

        let zoneID = CKRecordZone.ID(zoneName: group.zoneName, ownerName: group.ownerName)

        do {
            try await deleteRecordZone(in: privateDB, zoneID: zoneID)
        } catch {
            if let ck = error as? CKError, ck.code == .zoneNotFound {
                // Already gone -> treat as success.
            } else {
                throw error
            }
        }

        GroupContextStore.remove(groupId: group.id)
        await refresh()
    }

    /// Leaves a Shared group (removes it from the user's shared database).
    func leaveSharedGroup(_ group: GroupContext) async throws {
        guard group.scope == .shared else {
            throw NSError(domain: "CloudKitGroupStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Nur Shared-Gruppen können verlassen werden."])
        }

        let zoneID = CKRecordZone.ID(zoneName: group.zoneName, ownerName: group.ownerName)

        do {
            try await deleteRecordZone(in: sharedDB, zoneID: zoneID)
        } catch {
            if let ck = error as? CKError, ck.code == .zoneNotFound {
                // Already gone -> treat as success.
            } else {
                throw error
            }
        }

        GroupContextStore.remove(groupId: group.id)
        await refresh()
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

    // MARK: - Share hierarchy repair (record sharing)

    private func repairShareHierarchyIfNeeded(for group: GroupContext) async {
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
    private func repairShareHierarchy(for group: GroupContext) async throws {
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
                        print("CloudKitGroupStore: could not reparent \(type) record \(record.recordID.recordName): \(error)")
                    }
                }
            }
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

private func deleteRecordZone(in db: CKDatabase, zoneID: CKRecordZone.ID) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        db.delete(withRecordZoneID: zoneID) { _, error in
            if let error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: ())
            }
        }
    }
}
