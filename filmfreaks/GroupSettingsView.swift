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
        // In der UI wollen wir keine "Legacy"-Welt mehr sehen.
        // Wenn der Context (noch) nicht geladen ist, ist es trotzdem eine Cloud-Gruppe.
        return "Cloud"
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
            Text("Cloud-Gruppen")
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
