internal import SwiftUI

struct GroupSettingsMemberAvatarStackView: View {
    let members: [GroupSettingsActiveCardSnapshot.MemberPreview]
    let hiddenMemberCount: Int

    var body: some View {
        HStack(spacing: -9) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                GroupSettingsMemberAvatarView(name: member.name)
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
}

private struct GroupSettingsMemberAvatarView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let name: String

    var body: some View {
        Text(initials)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(displaySettings.tintColor)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(displaySettings.tintColor.opacity(0.12))
            )
            .overlay(
                Circle()
                    .stroke(Color(.secondarySystemBackground), lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)

        if parts.count >= 2 {
            let first = (parts.first ?? "").prefix(1)
            let last = (parts.last ?? "").prefix(1)
            return String(first + last).uppercased()
        }

        guard !trimmed.isEmpty else { return "??" }
        return String(trimmed.prefix(2)).uppercased()
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
