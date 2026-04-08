internal import SwiftUI

struct GroupSettingsActiveSectionView: View {
    let currentGroupName: String
    let activeGroupBadgeText: String
    let canShareActiveGroup: Bool
    let isPerformingGroupAction: Bool
    let onShareActiveGroup: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktive Gruppe")
                        .font(.headline)

                    Text(currentGroupName)
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

                Menu {
                    if canShareActiveGroup {
                        Button(action: onShareActiveGroup) {
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
    }
}

struct GroupSettingsCloudSectionView: View {
    @Binding var newCloudGroupName: String

    let ownedGroups: [GroupContext]
    let sharedGroups: [GroupContext]
    let currentGroupId: String?
    let isPerformingGroupAction: Bool
    let onCreateGroup: () -> Void
    let onSwitchGroup: (GroupContext) -> Void
    let onShareGroup: (GroupContext) -> Void
    let onDeleteGroup: (GroupContext) -> Void
    let onLeaveGroup: (GroupContext) -> Void

    private var trimmedGroupName: String {
        newCloudGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Neue Cloud-Gruppe")
                    .font(.headline)

                HStack {
                    TextField("Name", text: $newCloudGroupName)
                        .textInputAutocapitalization(.words)

                    Button("Erstellen", action: onCreateGroup)
                        .buttonStyle(.borderedProminent)
                        .disabled(trimmedGroupName.isEmpty)
                }
            }

            if ownedGroups.isEmpty && sharedGroups.isEmpty {
                Text("Noch keine Cloud-Gruppen. Erstell eine – oder tritt per iCloud-Einladung bei.")
                    .foregroundStyle(.secondary)
            }

            if !ownedGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Owned")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(ownedGroups) { group in
                        GroupSettingsCloudGroupRowView(
                            group: group,
                            currentGroupId: currentGroupId,
                            isPerformingGroupAction: isPerformingGroupAction,
                            canShare: true,
                            onSwitchGroup: onSwitchGroup,
                            onShareGroup: onShareGroup,
                            onDeleteGroup: onDeleteGroup,
                            onLeaveGroup: onLeaveGroup
                        )
                    }
                }
            }

            if !sharedGroups.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shared")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(sharedGroups) { group in
                        GroupSettingsCloudGroupRowView(
                            group: group,
                            currentGroupId: currentGroupId,
                            isPerformingGroupAction: isPerformingGroupAction,
                            canShare: false,
                            onSwitchGroup: onSwitchGroup,
                            onShareGroup: onShareGroup,
                            onDeleteGroup: onDeleteGroup,
                            onLeaveGroup: onLeaveGroup
                        )
                    }
                }
            }
        } header: {
            Text("Cloud-Gruppen")
        } footer: {
            Text("Owned-Gruppen kannst du löschen. Shared-Gruppen kannst du verlassen. Teilen läuft über iCloud-Einladung.")
        }
    }
}

struct GroupSettingsCloudGroupRowView: View {
    let group: GroupContext
    let currentGroupId: String?
    let isPerformingGroupAction: Bool
    let canShare: Bool
    let onSwitchGroup: (GroupContext) -> Void
    let onShareGroup: (GroupContext) -> Void
    let onDeleteGroup: (GroupContext) -> Void
    let onLeaveGroup: (GroupContext) -> Void

    var body: some View {
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

            if currentGroupId == group.id {
                Text("Aktiv")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            Menu {
                if currentGroupId != group.id {
                    Button {
                        onSwitchGroup(group)
                    } label: {
                        Label("Wechseln", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                if canShare {
                    Button {
                        onShareGroup(group)
                    } label: {
                        Label("Gruppe teilen", systemImage: "person.2.badge.plus")
                    }
                }

                Divider()

                if canShare {
                    Button(role: .destructive) {
                        onDeleteGroup(group)
                    } label: {
                        Label("Gruppe löschen", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        onLeaveGroup(group)
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
}
