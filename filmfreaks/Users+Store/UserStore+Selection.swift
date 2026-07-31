//
//  UserStore+Selection.swift
//  filmfreaks
//
//  Split from UserStore.swift
//

import Foundation

extension UserStore {

    // MARK: - Public selection / group loading API

    /// Wird aufgerufen, wenn die Gruppe wechselt (neue Gruppe / join / wechseln)
    func loadUsers(forGroupId groupId: String?) {
        currentGroupId = groupId

        // Switch the displayed sync status immediately when the group changes.
        applySyncStatusForCurrentGroup()

        // Erst lokal laden (schnelle UI), dann Cloud (Autorität für Gruppen).
        users = PersistenceManager.shared.loadUsers(groupId: groupId)

        // Lokale Änderungen dürfen durch einen frühen Cloud-Fetch nicht wieder verschwinden.
        restorePendingMemberCloudWrites(forGroupId: groupId)

        // Restore the previously selected user for this group (fallback: first user).
        restoreSelection(forGroupId: groupId)

        // Für Gruppen: direkt Cloud-Fetch.
        if let gid = groupId, !gid.isEmpty {
            Task { await self.refreshFromCloud(force: true) }
        }
    }

    // MARK: - Cloud apply

    func applyCloudUsers(members: [CloudKitUserStore.CloudMember], groupId: String) {
        let previousSelectedId = selectedUser?.id
        let previousSelectedName = selectedUser?.name
        let currentMemberIds = Set(members.map(\.id))

        // A remotely deleted member must not leave an orphaned profile image behind locally.
        for localMember in users where currentMemberIds.contains(localMember.id) == false {
            try? avatarStorage.removeAvatar(memberId: localMember.id, groupId: groupId)
        }

        for member in members {
            reconcileAvatarCache(
                for: member,
                previousAvatarVersion: users.first(where: { $0.id == member.id })?.avatarVersion,
                groupId: groupId
            )
        }

        let cloudUsers: [User] = members
            .map {
                User(
                    id: $0.id,
                    name: $0.name,
                    avatarVersion: $0.avatarVersion
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        isApplyingCloudUpdate = true
        users = cloudUsers
        isApplyingCloudUpdate = false

        // Persist cloud-applied state so members are still available offline / after app restart.
        PersistenceManager.shared.saveUsers(cloudUsers, groupId: groupId)

        if let prevId = previousSelectedId,
           let match = users.first(where: { $0.id == prevId }) {
            selectedUser = match
            return
        }

        if let prevName = previousSelectedName,
           let match = users.first(where: { $0.name.caseInsensitiveCompare(prevName) == .orderedSame }) {
            selectedUser = match
            return
        }

        // If previous selection is missing (e.g. user deleted / id changed), fall back to persisted selection.
        restoreSelection(forGroupId: groupId)
    }

    // MARK: - Selection restore

    func restoreSelection(forGroupId groupId: String?) {
        guard !users.isEmpty else {
            selectedUser = nil
            return
        }

        // 1) Per-group persisted selection (the new canonical source)
        if let storedId = SelectedUserSelectionStore.selectedUserId(groupId: groupId),
           let match = users.first(where: { $0.id == storedId }) {
            selectedUser = match
            return
        }

        if let storedName = SelectedUserSelectionStore.selectedUserName(groupId: groupId) {
            let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               let match = users.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                selectedUser = match
                return
            }
        }

        // 2) Legacy fallback: global "current user" (used by notifications). If it matches this group's users,
        // we treat it as the selection and automatically migrate it into the per-group store via didSet.
        if let legacyId = CurrentUserIdentityStore.currentUserId(),
           let match = users.first(where: { $0.id == legacyId }) {
            selectedUser = match
            return
        }

        if let legacyName = CurrentUserIdentityStore.currentUserName() {
            let trimmed = legacyName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               let match = users.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                selectedUser = match
                return
            }
        }

        // 3) Fallback
        selectedUser = users.first
    }
}
