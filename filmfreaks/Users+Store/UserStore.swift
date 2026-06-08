//
//  UserStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
import Combine
internal import SwiftUI

@MainActor
class UserStore: ObservableObject {

    // MARK: - Sync status model

    struct SyncStatus: Codable, Equatable {
        var lastSuccessAt: Date?
        var lastAttemptAt: Date?
        var lastErrorMessage: String?
        var lastErrorAt: Date?
    }

    static let syncStatusByGroupKey = GroupScopedStorage.UserDefaultsKey.userStoreSyncStatusByGroup

    // MARK: - Public state

    @Published var users: [User] = [] {
        didSet {
            if isApplyingCloudUpdate { return }
            PersistenceManager.shared.saveUsers(users, groupId: currentGroupId)
        }
    }

    /// Wer gerade bewertet etc.
    @Published var selectedUser: User? {
        didSet {
            // Persist per-group selection so the app can restore the active member on next launch.
            SelectedUserSelectionStore.setSelectedUser(
                groupId: currentGroupId,
                userId: selectedUser?.id,
                userName: selectedUser?.name
            )

            // P2 full: Persist current identity so we can suppress notifications for own actions.
            // (Global "best effort" identity — used by the notification layer.)
            CurrentUserIdentityStore.setCurrentUser(id: selectedUser?.id, name: selectedUser?.name)
        }
    }

    /// Wird gesetzt, während wir Members aus iCloud laden oder Änderungen pushen.
    @Published var isSyncing: Bool = false

    // MARK: - Sync UX / Trust (subtle status indicators)

    /// Last time we successfully fetched or wrote members to iCloud.
    @Published var lastCloudSyncSuccessAt: Date?

    /// Last time we attempted any member sync.
    @Published var lastCloudSyncAttemptAt: Date?

    /// Human-readable last iCloud sync error (if any).
    @Published var lastCloudSyncErrorMessage: String?

    /// When the last iCloud sync error happened.
    @Published var lastCloudSyncErrorAt: Date?

    // MARK: - Internal state for split responsibilities

    var syncStatusByGroup: [String: SyncStatus] = [:]

    /// Zu welcher Gruppe gehören diese `users`?
    var currentGroupId: String?

    /// CloudKit-Backend (Members).
    let cloudStore = CloudKitUserStore()

    /// Verhindert didSet-Schleifen beim Cloud-Apply.
    var isApplyingCloudUpdate: Bool = false

    /// Throttle gegen „zu viele“ Fetches (z.B. App wird aktiv + Pull-to-refresh kurz hintereinander).
    var lastRefreshAt: Date?
    let minRefreshInterval: TimeInterval = 8

    // MARK: - Init

    init() {
        // Per-group sync status (so Settings show the right group)
        syncStatusByGroup = Self.loadSyncStatusByGroup()

        // gleiche Group-ID wie MovieStore verwenden
        let groupIdFromDefaults = UserDefaults.standard.string(forKey: GroupScopedStorage.UserDefaultsKey.currentGroupId)
        currentGroupId = groupIdFromDefaults

        // Ensure published status matches the current group immediately.
        applySyncStatusForCurrentGroup()

        users = PersistenceManager.shared.loadUsers(groupId: groupIdFromDefaults)

        // Restore the previously selected user for this group (fallback: first user).
        restoreSelection(forGroupId: groupIdFromDefaults)

        // Falls wir direkt in einer Gruppe sind: Members aus iCloud nachladen.
        if let gid = groupIdFromDefaults, !gid.isEmpty {
            Task { await self.refreshFromCloud(force: true) }
        }
    }
}
