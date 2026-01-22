//
//  GroupSettingsView.swift
//  filmfreaks
//
//  Gruppenverwaltung: Legacy (Invite-Code) + neue CloudKit-Sharing Gruppen.
//

internal import SwiftUI
import CloudKit

struct GroupSettingsView: View {
    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var groupStore: CloudKitGroupStore

    @State private var newCloudGroupName: String = ""

    @State private var isMigratingLegacy = false
    @State private var migrateError: String?

    @State private var shareToPresent: CKShare?

    @State private var pendingGroupAction: PendingGroupAction?
    @State private var isPerformingGroupAction = false

    // MARK: - Active group helpers

    private var activeContext: GroupContext? {
        guard let gid = movieStore.currentGroupId, !gid.isEmpty else { return nil }
        return GroupContextStore.context(forGroupId: gid)
    }

    private var activeGroupBadgeText: String {
        if movieStore.currentGroupId == nil {
            return "Lokal"
        }
        if let ctx = activeContext {
            return ctx.isShared ? "Shared" : "Owned"
        }
        return "Legacy"
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktive Gruppe")
                            .font(.headline)

                        Text(movieStore.currentGroupName ?? "Standard")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(activeGroupBadgeText)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())

                    // Alle Aktionen hinter "Optionen"
                    Menu {
                        if let ctx = activeContext, !ctx.isShared {
                            Button {
                                Task {
                                    do {
                                        let share = try await groupStore.fetchOrCreateShare(for: ctx)
                                        shareToPresent = share
                                    } catch {
                                        migrateError = error.localizedDescription
                                    }
                                }
                            } label: {
                                Label("Gruppe teilen", systemImage: "person.2.badge.plus")
                            }
                        }
                    } label: {
                        Label("Optionen", systemImage: "ellipsis.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPerformingGroupAction)
                    .accessibilityLabel("Optionen")
                }
            }

            cloudSection

            legacySection
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
            groupActionTitle,
            isPresented: Binding(
                get: { pendingGroupAction != nil },
                set: { if !$0 { pendingGroupAction = nil } }
            )
        ) {
            if let action = pendingGroupAction {
                switch action.kind {
                case .deleteOwned:
                    Button("Gruppe löschen", role: .destructive) {
                        let a = action
                        pendingGroupAction = nil
                        Task { await executeGroupAction(a) }
                    }
                case .leaveShared:
                    Button("Gruppe verlassen", role: .destructive) {
                        let a = action
                        pendingGroupAction = nil
                        Task { await executeGroupAction(a) }
                    }
                }
            }

            Button("Abbrechen", role: .cancel) {
                pendingGroupAction = nil
            }
        } message: {
            Text(groupActionMessage)
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

    // MARK: - Cloud UI

    private var cloudSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Neue Cloud-Gruppe")
                    .font(.headline)

                HStack {
                    TextField("Name", text: $newCloudGroupName)
                        .textInputAutocapitalization(.words)

                    Button("Erstellen") {
                        Task {
                            do {
                                let g = try await groupStore.createGroup(name: newCloudGroupName)
                                newCloudGroupName = ""
                                movieStore.activateCloudGroup(g)
                                userStore.loadUsers(forGroupId: g.id)
                                await movieStore.refreshFromCloud(force: true)
                                await groupStore.refresh() // ensures list updates immediately
                            } catch {
                                migrateError = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newCloudGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if groupStore.ownedGroups.isEmpty && groupStore.sharedGroups.isEmpty {
                Text("Noch keine Cloud-Gruppen. Erstell eine – oder tritt per iCloud-Einladung bei.")
                    .foregroundStyle(.secondary)
            }

            if !groupStore.ownedGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Owned")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(groupStore.ownedGroups) { g in
                        cloudGroupRow(group: g, canShare: true)
                    }
                }
            }

            if !groupStore.sharedGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shared")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(groupStore.sharedGroups) { g in
                        cloudGroupRow(group: g, canShare: false)
                    }
                }
            }
        } header: {
            Text("Cloud-Gruppen (neu)")
        } footer: {
            Text("Owned-Gruppen kannst du löschen. Shared-Gruppen kannst du verlassen. Teilen läuft über iCloud-Einladung.")
        }
    }

    @ViewBuilder
    private func cloudGroupRow(group: GroupContext, canShare: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                    .lineLimit(1)
                Text(group.isShared ? "Shared" : "Owned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if movieStore.currentGroupId == group.id {
                Text("Aktiv")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            // Alles hinter "Optionen" (Wechseln, Teilen, Löschen/Verlassen)
            Menu {
                if movieStore.currentGroupId != group.id {
                    Button {
                        movieStore.activateCloudGroup(group)
                        userStore.loadUsers(forGroupId: group.id)
                        Task {
                            await movieStore.refreshFromCloud(force: true)
                            await groupStore.refresh() // keep list consistent after switch
                        }
                    } label: {
                        Label("Wechseln", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                if canShare {
                    Button {
                        Task {
                            do {
                                let share = try await groupStore.fetchOrCreateShare(for: group)
                                shareToPresent = share
                            } catch {
                                migrateError = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Gruppe teilen", systemImage: "person.2.badge.plus")
                    }
                }

                Divider()

                if canShare {
                    Button(role: .destructive) {
                        pendingGroupAction = PendingGroupAction(kind: .deleteOwned, group: group)
                    } label: {
                        Label("Gruppe löschen", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        pendingGroupAction = PendingGroupAction(kind: .leaveShared, group: group)
                    } label: {
                        Label("Gruppe verlassen", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Label("Optionen", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.bordered)
            .disabled(isPerformingGroupAction)
            .accessibilityLabel("Optionen")
        }
    }

    // MARK: - Legacy UI

    private var legacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Legacy-Gruppen (Altbestand)")
                    .font(.headline)

                Text("Beitritt ist deaktiviert. Hier siehst du nur Legacy-Gruppen, die diese App bereits kennt. Migration ist nur möglich, wenn die Legacy-Gruppe aktuell aktiv ist.")
                    .foregroundStyle(.secondary)
            }

            let legacyKnown = movieStore.knownGroups.filter { GroupContextStore.context(forGroupId: $0.id) == nil }

            if legacyKnown.isEmpty {
                Text("Keine bekannten Legacy-Gruppen.")
                    .foregroundStyle(.secondary)
            } else {
                DisclosureGroup("Bekannte Legacy-Gruppen") {
                    ForEach(legacyKnown) { g in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.displayName)
                                    .font(.body)
                                    .lineLimit(1)
                                Text("Legacy")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if movieStore.currentGroupId == g.id {
                                Text("Aktiv")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }

                            Button(role: .destructive) {
                                movieStore.knownGroups.removeAll { $0.id == g.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if canUpgradeCurrentLegacyGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upgrade")
                        .font(.headline)

                    Text("Du bist gerade in einer Legacy-Gruppe. Upgrade migriert alle Daten in eine neue Cloud-Gruppe, die du anschließend per iCloud teilen kannst.")
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await migrateCurrentLegacyGroup() }
                    } label: {
                        HStack {
                            if isMigratingLegacy {
                                ProgressView()
                            }
                            Text(isMigratingLegacy ? "Migriere…" : "Upgrade zu Cloud-Gruppe")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isMigratingLegacy)
                }
                .padding(.vertical, 6)
            }

        } header: {
            Text("Legacy (Invite-Code / Public DB)")
        } footer: {
            Text("Legacy bleibt erstmal drin, aber sobald du upgraden kannst: mach’s. Public DB ist ein unnötiger Bauchladen.")
        }
    }

    private var canUpgradeCurrentLegacyGroup: Bool {
        guard let gid = movieStore.currentGroupId, !gid.isEmpty else { return false }
        return GroupContextStore.context(forGroupId: gid) == nil
    }

    private func migrateCurrentLegacyGroup() async {
        guard let legacyId = movieStore.currentGroupId, !legacyId.isEmpty else { return }
        isMigratingLegacy = true
        defer { isMigratingLegacy = false }

        do {
            let newGroup = try await LegacyGroupMigrationService().migrateLegacyGroup(
                legacyGroupId: legacyId,
                legacyGroupName: movieStore.currentGroupName,
                groupStore: groupStore
            )

            // Remove the old legacy group from the quick list to avoid "which one is the real one?"
            movieStore.knownGroups.removeAll { $0.id == legacyId }

            movieStore.activateCloudGroup(newGroup)
            await movieStore.refreshFromCloud(force: true)
            await userStore.refreshFromCloud(force: true)
            await groupStore.refresh()
        } catch {
            migrateError = error.localizedDescription
        }
    }

    // MARK: - Delete / Leave

    private enum GroupActionKind {
        case deleteOwned
        case leaveShared
    }

    private struct PendingGroupAction: Identifiable {
        let id = UUID()
        let kind: GroupActionKind
        let group: GroupContext
    }

    private var groupActionTitle: String {
        guard let action = pendingGroupAction else { return "" }
        switch action.kind {
        case .deleteOwned: return "Gruppe löschen?"
        case .leaveShared: return "Gruppe verlassen?"
        }
    }

    private var groupActionMessage: String {
        guard let action = pendingGroupAction else { return "" }
        switch action.kind {
        case .deleteOwned:
            return "„\(action.group.name)“ wird endgültig gelöscht (Cloud + lokaler Cache). Das kann nicht rückgängig gemacht werden."
        case .leaveShared:
            return "Du verlässt „\(action.group.name)“. Du kannst später nur per Einladung wieder beitreten."
        }
    }

    private func executeGroupAction(_ action: PendingGroupAction) async {
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

            // Local cleanup
            PersistenceManager.shared.deleteGroupData(groupId: action.group.id)
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
