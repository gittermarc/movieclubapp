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

    // MARK: - Published

    @Published private(set) var ownedGroups: [GroupContext] = []
    @Published private(set) var sharedGroups: [GroupContext] = []

    // MARK: - Dependencies

    let container: CKContainer
    var privateDB: CKDatabase { container.privateCloudDatabase }
    var sharedDB: CKDatabase { container.sharedCloudDatabase }

    let subscriptionManager: CloudKitActivitySubscriptionManager

    // MARK: - CloudKit schema

    static let groupRecordType = "FFGroup"
    static let nameKey = "name"
    static let createdAtKey = "createdAt"

    private var lastICloudProblemToastAt: Date?

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

    // MARK: - Public API

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

            // Ensure CloudKit subscriptions exist so changes can wake the app via
            // content-available pushes (later -> map to local notifications).
            Task {
                await ensureSubscriptions(forOwnedGroups: owned, forSharedGroups: shared)
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

    func createGroup(name: String) async throws -> GroupContext {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupId = UUID().uuidString
        let zoneName = "group.\(groupId)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        // Create zone (idempotent).
        _ = try await createZoneIfNeeded(zoneID: zoneID)

        let recordID = CKRecord.ID(recordName: groupId, zoneID: zoneID)
        let record = CKRecord(recordType: Self.groupRecordType, recordID: recordID)
        record[Self.nameKey] = trimmed as CKRecordValue
        record[Self.createdAtKey] = Date() as CKRecordValue
        _ = try await privateDB.save(record)

        let ctx = GroupContext(
            id: groupId,
            name: trimmed,
            scope: .private,
            zoneName: zoneName,
            ownerName: CKCurrentUserDefaultName
        )
        GroupContextStore.upsert(ctx)

        await refresh()
        return ctx
    }

    // MARK: - Delete / Leave

    /// Deletes an Owned group (the current user is the owner).
    /// This removes the entire record zone in the private database (including all movies/ratings/goals/members).
    func deleteOwnedGroup(_ group: GroupContext) async throws {
        guard group.scope == .private else {
            throw NSError(
                domain: "CloudKitGroupStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Nur Owned-Gruppen können gelöscht werden."]
            )
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
            throw NSError(
                domain: "CloudKitGroupStore",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Nur Shared-Gruppen können verlassen werden."]
            )
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

    // MARK: - Account / UX

    func fetchAccountStatus() async throws -> CKAccountStatus {
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

    func maybeShowICloudProblemToast(status: CKAccountStatus) {
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
}
