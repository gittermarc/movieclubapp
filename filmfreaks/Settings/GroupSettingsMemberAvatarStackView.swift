internal import SwiftUI

struct GroupSettingsMemberAvatarStackView: View {
    @EnvironmentObject private var userStore: UserStore

    let members: [GroupSettingsActiveCardSnapshot.MemberPreview]
    let hiddenMemberCount: Int

    var body: some View {
        HStack(spacing: -9) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                GroupSettingsMemberAvatarView(
                    member: resolvedMember(for: member),
                    groupId: userStore.currentGroupId
                )
                    .zIndex(Double(members.count - index))
            }

            if hiddenMemberCount > 0 {
                GroupSettingsHiddenMembersBadge(count: hiddenMemberCount)
                    .zIndex(0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let visibleNames = members.map(\.name)
        let visiblePart = visibleNames.joined(separator: ", ")

        if hiddenMemberCount > 0, !visiblePart.isEmpty {
            return "Mitglieder: \(visiblePart) und \(hiddenMemberCount) weitere"
        }
        if !visiblePart.isEmpty {
            return "Mitglieder: \(visiblePart)"
        }
        return "Keine Mitglieder"
    }

    private func resolvedMember(for preview: GroupSettingsActiveCardSnapshot.MemberPreview) -> User {
        userStore.users.first(where: { $0.id == preview.id })
            ?? User(id: preview.id, name: preview.name)
    }
}

private struct GroupSettingsMemberAvatarView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let member: User
    let groupId: String?

    var body: some View {
        MemberAvatarView(
            member: member,
            groupId: groupId,
            size: 28,
            tintColor: displaySettings.tintColor
        )
            .overlay(
                Circle()
                    .stroke(Color(.secondarySystemBackground), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }
}

private struct GroupSettingsHiddenMembersBadge: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(displaySettings.tintColor)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(displaySettings.tintColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color(.secondarySystemBackground), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }
}
