//
//  GroupSettingsView.swift
//  filmfreaks
//
//  Gruppenverwaltung: CloudKit-Sharing Gruppen.
//

internal import SwiftUI
import CloudKit

struct GroupSettingsView: View {
    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var groupStore: CloudKitGroupStore

    @State private var newCloudGroupName: String = ""
    @State private var migrateError: String?

    @State private var shareToPresent: CKShare?

    @State private var pendingGroupAction: GroupSettingsPendingAction?
    @State private var isPerformingGroupAction = false

    private var activeContext: GroupContext? {
        guard let gid = movieStore.currentGroupId, !gid.isEmpty else { return nil }
        return GroupContextStore.context(forGroupId: gid)
    }

    private var activeGroupBadgeText: String {
        GroupSettingsPresentation.activeGroupBadgeText(
            currentGroupId: movieStore.currentGroupId,
            activeContext: activeContext
        )
    }

    private var canShareActiveGroup: Bool {
        guard let activeContext else { return false }
        return !activeContext.isShared
    }

    var body: some View {
        Form {
            GroupSettingsActiveSectionView(
                currentGroupName: movieStore.currentGroupName ?? "Standard",
                activeGroupBadgeText: activeGroupBadgeText,
                canShareActiveGroup: canShareActiveGroup,
                isPerformingGroupAction: isPerformingGroupAction,
                onShareActiveGroup: shareActiveGroup
            )

            GroupSettingsCloudSectionView(
                newCloudGroupName: $newCloudGroupName,
                ownedGroups: groupStore.ownedGroups,
                sharedGroups: groupStore.sharedGroups,
                currentGroupId: movieStore.currentGroupId,
                isPerformingGroupAction: isPerformingGroupAction,
                onCreateGroup: createCloudGroup,
                onSwitchGroup: switchToGroup,
                onShareGroup: shareGroup,
                onDeleteGroup: requestDeleteGroup,
                onLeaveGroup: requestLeaveGroup
            )
        }
        .navigationTitle("Gruppen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await groupStore.refresh()
        }
        .sheet(
            isPresented: Binding(
                get: { shareToPresent != nil },
                set: { if !$0 { shareToPresent = nil } }
            )
        ) {
            if shareToPresent != nil {
                GroupShareSheetView(
                    container: CKContainer.default(),
                    share: Binding(
                        get: { shareToPresent! },
                        set: { shareToPresent = $0 }
                    )
                )
            } else {
                EmptyView()
            }
        }
        .confirmationDialog(
            pendingGroupAction?.title ?? "",
            isPresented: Binding(
                get: { pendingGroupAction != nil },
                set: { if !$0 { pendingGroupAction = nil } }
            )
        ) {
            if let action = pendingGroupAction {
                switch action.kind {
                case .deleteOwned:
                    Button("Gruppe löschen", role: .destructive) {
                        let pendingAction = action
                        pendingGroupAction = nil
                        Task { await executeGroupAction(pendingAction) }
                    }
                case .leaveShared:
                    Button("Gruppe verlassen", role: .destructive) {
                        let pendingAction = action
                        pendingGroupAction = nil
                        Task { await executeGroupAction(pendingAction) }
                    }
                }
            }

            Button("Abbrechen", role: .cancel) {
                pendingGroupAction = nil
            }
        } message: {
            Text(pendingGroupAction?.message ?? "")
        }
        .alert(
            "Aktion fehlgeschlagen",
            isPresented: Binding(
                get: { migrateError != nil },
                set: { if !$0 { migrateError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(migrateError ?? "")
        }
    }

    private func createCloudGroup() {
        Task {
            do {
                let group = try await groupStore.createGroup(name: newCloudGroupName)
                newCloudGroupName = ""
                movieStore.activateCloudGroup(group)
                userStore.loadUsers(forGroupId: group.id)
                await movieStore.refreshFromCloud(force: true)
                await groupStore.refresh()
            } catch {
                migrateError = error.localizedDescription
            }
        }
    }

    private func switchToGroup(_ group: GroupContext) {
        movieStore.activateCloudGroup(group)
        userStore.loadUsers(forGroupId: group.id)

        Task {
            await movieStore.refreshFromCloud(force: true)
            await groupStore.refresh()
        }
    }

    private func shareActiveGroup() {
        guard let activeContext, !activeContext.isShared else { return }
        shareGroup(activeContext)
    }

    private func shareGroup(_ group: GroupContext) {
        Task {
            do {
                let share = try await groupStore.fetchOrCreateShare(for: group)
                shareToPresent = share
            } catch {
                migrateError = error.localizedDescription
            }
        }
    }

    private func requestDeleteGroup(_ group: GroupContext) {
        pendingGroupAction = GroupSettingsPendingAction(kind: .deleteOwned, group: group)
    }

    private func requestLeaveGroup(_ group: GroupContext) {
        pendingGroupAction = GroupSettingsPendingAction(kind: .leaveShared, group: group)
    }

    private func executeGroupAction(_ action: GroupSettingsPendingAction) async {
        guard !isPerformingGroupAction else { return }
        isPerformingGroupAction = true
        defer { isPerformingGroupAction = false }

        do {
            switch action.kind {
            case .deleteOwned:
                try await groupStore.deleteOwnedGroup(action.group)
            case .leaveShared:
                try await groupStore.leaveSharedGroup(action.group)
            }

            PersistenceManager.shared.deleteGroupData(groupId: action.group.id)
            SelectedUserSelectionStore.setSelectedUser(groupId: action.group.id, userId: nil, userName: nil)
            movieStore.knownGroups.removeAll { $0.id == action.group.id }

            if movieStore.currentGroupId == action.group.id {
                movieStore.leaveCurrentGroup()
                userStore.loadUsers(forGroupId: nil)
            }
        } catch {
            migrateError = error.localizedDescription
        }
    }
}
