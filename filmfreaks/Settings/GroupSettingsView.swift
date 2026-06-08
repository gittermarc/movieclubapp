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
    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var groupStore: CloudKitGroupStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    @State private var newCloudGroupName: String = ""
    @State private var migrateError: String?

    @State private var shareToPresent: CKShare?

    @State private var pendingGroupAction: GroupSettingsPendingAction?
    @State private var isPerformingGroupAction = false
    @StateObject private var activeCardModel = GroupSettingsActiveCardSnapshotModel()

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

    private var activeGroupDescription: String {
        GroupSettingsPresentation.activeGroupDescription(
            currentGroupId: movieStore.currentGroupId,
            activeContext: activeContext
        )
    }

    private var activeGroupSummaryText: String {
        GroupSettingsPresentation.activeGroupSummary(
            memberCount: userStore.users.count,
            watchedCount: movieStore.movies.count,
            backlogCount: movieStore.backlogMovies.count
        )
    }

    private var normalizedCurrentGroupId: String {
        (movieStore.currentGroupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canShareActiveGroup: Bool {
        guard let activeContext else { return false }
        return !activeContext.isShared
    }

    private var canSwitchToLocalGroup: Bool {
        movieStore.currentGroupId != nil
    }

    private var hasCloudGroups: Bool {
        !groupStore.ownedGroups.isEmpty || !groupStore.sharedGroups.isEmpty
    }

    private var horizontalPadding: CGFloat {
        max(16, displaySettings.metrics.cardPadding + 6)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                GroupSettingsHeroCardView(
                    currentGroupName: movieStore.currentGroupName ?? "Standard",
                    activeGroupBadgeText: activeGroupBadgeText,
                    detailText: activeGroupDescription,
                    summaryText: activeGroupSummaryText,
                    snapshot: activeCardModel.snapshot,
                    canShareActiveGroup: canShareActiveGroup,
                    canSwitchToLocalGroup: canSwitchToLocalGroup,
                    isPerformingGroupAction: isPerformingGroupAction,
                    onShareActiveGroup: shareActiveGroup,
                    onSwitchToLocalGroup: switchToLocalGroup
                )

                VStack(alignment: .leading, spacing: 14) {
                    GroupSettingsSectionHeaderView(
                        title: "Gruppe wechseln",
                        subtitle: "Hier bestimmst du, in welchem Raum gerade Filme, Backlog und Mitglieder verwaltet werden."
                    )

                    GroupSettingsGroupCardView(
                        title: GroupSettingsPresentation.localGroupTitle(),
                        subtitle: "Lokale Standardgruppe",
                        detailText: GroupSettingsPresentation.localGroupDetailText(),
                        badgeText: "Lokal",
                        isActive: movieStore.currentGroupId == nil,
                        isPerformingGroupAction: isPerformingGroupAction,
                        primaryActionTitle: "Lokal nutzen",
                        primaryActionSystemImage: "iphone",
                        onPrimaryAction: switchToLocalGroup,
                        onShareAction: nil,
                        destructiveActionTitle: nil,
                        destructiveActionSystemImage: nil,
                        onDestructiveAction: nil
                    )

                    if !groupStore.ownedGroups.isEmpty {
                        GroupSettingsSectionHeaderView(title: "Eigene Gruppen", subtitle: nil)

                        ForEach(groupStore.ownedGroups) { group in
                            GroupSettingsGroupCardView(
                                title: group.name,
                                subtitle: GroupSettingsPresentation.groupKindText(for: group),
                                detailText: GroupSettingsPresentation.groupDetailText(for: group),
                                badgeText: GroupSettingsPresentation.groupKindText(for: group),
                                isActive: movieStore.currentGroupId == group.id,
                                isPerformingGroupAction: isPerformingGroupAction,
                                primaryActionTitle: "Wechseln",
                                primaryActionSystemImage: "arrow.triangle.2.circlepath",
                                onPrimaryAction: { switchToGroup(group) },
                                onShareAction: { shareGroup(group) },
                                destructiveActionTitle: "Gruppe löschen",
                                destructiveActionSystemImage: "trash",
                                onDestructiveAction: { requestDeleteGroup(group) }
                            )
                        }
                    }

                    if !groupStore.sharedGroups.isEmpty {
                        GroupSettingsSectionHeaderView(title: "Geteilte Gruppen", subtitle: nil)

                        ForEach(groupStore.sharedGroups) { group in
                            GroupSettingsGroupCardView(
                                title: group.name,
                                subtitle: GroupSettingsPresentation.groupKindText(for: group),
                                detailText: GroupSettingsPresentation.groupDetailText(for: group),
                                badgeText: GroupSettingsPresentation.groupKindText(for: group),
                                isActive: movieStore.currentGroupId == group.id,
                                isPerformingGroupAction: isPerformingGroupAction,
                                primaryActionTitle: "Wechseln",
                                primaryActionSystemImage: "arrow.triangle.2.circlepath",
                                onPrimaryAction: { switchToGroup(group) },
                                onShareAction: nil,
                                destructiveActionTitle: "Gruppe verlassen",
                                destructiveActionSystemImage: "rectangle.portrait.and.arrow.right",
                                onDestructiveAction: { requestLeaveGroup(group) }
                            )
                        }
                    }

                    if !hasCloudGroups {
                        GroupSettingsEmptyStateCardView(
                            message: GroupSettingsPresentation.emptyCloudGroupsMessage()
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    GroupSettingsSectionHeaderView(
                        title: "Neue Gruppe erstellen",
                        subtitle: "Eine eigene Cloud-Gruppe ist ideal für Filmabende mit Freunden oder geteilte Backlogs."
                    )

                    GroupSettingsCreateGroupCardView(
                        newCloudGroupName: $newCloudGroupName,
                        isDisabled: isPerformingGroupAction,
                        onCreateGroup: createCloudGroup
                    )
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Gruppen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            updateActiveCardSnapshot()
            await refreshScreen(forceMovieNightRefresh: false)
            updateActiveCardSnapshot()
        }
        .refreshable {
            await refreshScreen(forceMovieNightRefresh: true)
            updateActiveCardSnapshot()
        }
        .onReceive(userStore.$users) { _ in
            updateActiveCardSnapshot()
        }
        .onReceive(movieStore.$movies) { _ in
            updateActiveCardSnapshot()
        }
        .onReceive(movieStore.$backlogMovies) { _ in
            updateActiveCardSnapshot()
        }
        .onReceive(movieStore.$currentGroupId) { _ in
            updateActiveCardSnapshot()
        }
        .onReceive(movieNightStore.$activityByGroup) { _ in
            updateActiveCardSnapshot()
        }
        .onReceive(displaySettings.$ratingDisplayMode) { _ in
            updateActiveCardSnapshot()
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


    private func updateActiveCardSnapshot() {
        activeCardModel.update(
            input: GroupSettingsActiveCardSnapshotInput(
                users: userStore.users,
                movieEvents: movieStore.activityEvents(displayMode: displaySettings.ratingDisplayMode, limit: 24),
                movieNightEvents: movieNightStore.activityEvents(for: normalizedCurrentGroupId),
                movies: movieStore.movies,
                backlogMovies: movieStore.backlogMovies
            )
        )
    }

    private func createCloudGroup() {
        Task {
            do {
                let group = try await groupStore.createGroup(name: newCloudGroupName)
                newCloudGroupName = ""
                movieStore.activateCloudGroup(group)
                userStore.loadUsers(forGroupId: group.id)
                await movieStore.refreshFromCloud(force: true)
                await movieNightStore.refreshFromCloud(groupId: group.id, force: true)
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
            await movieNightStore.refreshFromCloud(groupId: group.id, force: true)
            await groupStore.refresh()
        }
    }

    private func switchToLocalGroup() {
        movieStore.activateLocalGroup()
        userStore.loadUsers(forGroupId: nil)

        Task {
            await movieNightStore.refreshFromCloud(groupId: nil, force: true)
            await groupStore.refresh()
        }
    }

    private func refreshScreen(forceMovieNightRefresh: Bool) async {
        await groupStore.refresh()
        await movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: forceMovieNightRefresh)
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
                movieStore.activateLocalGroup()
                userStore.loadUsers(forGroupId: nil)
            }
        } catch {
            migrateError = error.localizedDescription
        }
    }
}
