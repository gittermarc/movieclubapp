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
    @State private var legacyInviteCode: String = ""

    @State private var isMigratingLegacy = false
    @State private var migrateError: String?

    @State private var shareToPresent: CKShare?

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
                            Image(systemName: "person.2.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Gruppe teilen")
                    }
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
        .sheet(item: shareBinding) { wrapper in
            CloudSharingControllerView(container: CKContainer.default(), share: wrapper.share)
                .ignoresSafeArea()
        }
        .alert("Migration fehlgeschlagen", isPresented: Binding(get: { migrateError != nil }, set: { if !$0 { migrateError = nil } })) {
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
            Text("Cloud-Gruppen sind privat/shared (nicht mehr Public DB). Teilen läuft über iCloud-Einladung.")
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
            } else {
                Button("Wechseln") {
                    movieStore.activateCloudGroup(group)
                    userStore.loadUsers(forGroupId: group.id)
                    Task {
                        await movieStore.refreshFromCloud(force: true)
                        await groupStore.refresh() // keep list consistent after switch
                    }
                }
                .buttonStyle(.bordered)
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
                    Image(systemName: "person.2.badge.plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Gruppe teilen")
            }
        }
    }

    // MARK: - Legacy UI

    private var legacySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Legacy-Gruppe beitreten")
                    .font(.headline)

                HStack {
                    TextField("Invite-Code", text: $legacyInviteCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Beitreten") {
                        let code = legacyInviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !code.isEmpty else { return }
                        movieStore.joinGroup(withInviteCode: code)
                        userStore.loadUsers(forGroupId: code)
                        legacyInviteCode = ""
                    }
                    .buttonStyle(.bordered)
                }
            }

            let legacyKnown = movieStore.knownGroups.filter { GroupContextStore.context(forGroupId: $0.id) == nil }

            if !legacyKnown.isEmpty {
                DisclosureGroup("Bekannte Legacy-Gruppen") {
                    ForEach(legacyKnown) { g in
                        HStack {
                            Button {
                                movieStore.joinGroup(withInviteCode: g.id)
                                userStore.loadUsers(forGroupId: g.id)
                            } label: {
                                HStack {
                                    Text(g.name ?? "Unnamed")
                                    Spacer()
                                    if movieStore.currentGroupId == g.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

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
                        Task {
                            await migrateCurrentLegacyGroup()
                        }
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

    // Sheet helper
    private var shareBinding: Binding<ShareWrapper?> {
        Binding(
            get: { shareToPresent.map { ShareWrapper(share: $0) } },
            set: { shareToPresent = $0?.share }
        )
    }
}

private struct ShareWrapper: Identifiable {
    let id = UUID()
    let share: CKShare
}
