internal import SwiftUI

struct GroupSettingsSectionHeaderView: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GroupSettingsCardContainer<Content: View>: View {
    @EnvironmentObject private var displaySettings: DisplaySettings
    let isHighlighted: Bool
    let content: Content

    init(isHighlighted: Bool = false, @ViewBuilder content: () -> Content) {
        self.isHighlighted = isHighlighted
        self.content = content()
    }

    var body: some View {
        content
            .padding(displaySettings.metrics.cardPadding + 4)
            .background(
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: isHighlighted ? 1.5 : 1)
            )
            .shadow(color: shadowColor, radius: isHighlighted ? 12 : 5, x: 0, y: isHighlighted ? 6 : 2)
    }

    private var borderColor: Color {
        if isHighlighted {
            return displaySettings.tintColor.opacity(0.32)
        }
        return Color.primary.opacity(0.06)
    }

    private var shadowColor: Color {
        if isHighlighted {
            return displaySettings.tintColor.opacity(0.10)
        }
        return Color.black.opacity(0.04)
    }
}

struct GroupSettingsHeroCardView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let currentGroupName: String
    let activeGroupBadgeText: String
    let detailText: String
    let summaryText: String
    let canShareActiveGroup: Bool
    let canSwitchToLocalGroup: Bool
    let isPerformingGroupAction: Bool
    let onShareActiveGroup: () -> Void
    let onSwitchToLocalGroup: () -> Void

    var body: some View {
        GroupSettingsCardContainer(isHighlighted: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(displaySettings.tintColor.opacity(0.14))
                            .frame(width: 48, height: 48)

                        Image(systemName: "person.3.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(displaySettings.tintColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aktive Gruppe")
                            .font(.headline)

                        Text(currentGroupName)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)

                        Text(detailText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    GroupSettingsBadgeView(text: activeGroupBadgeText)
                }

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if canShareActiveGroup || canSwitchToLocalGroup {
                    ViewThatFits {
                        HStack(spacing: 10) {
                            actionButtons
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            actionButtons
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if canShareActiveGroup {
            Button(action: onShareActiveGroup) {
                Label("Gruppe teilen", systemImage: "person.2.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPerformingGroupAction)
        }

        if canSwitchToLocalGroup {
            Button(action: onSwitchToLocalGroup) {
                Label("Zu lokal wechseln", systemImage: "iphone")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isPerformingGroupAction)
        }
    }
}

struct GroupSettingsGroupCardView: View {
    let title: String
    let subtitle: String
    let detailText: String
    let badgeText: String
    let isActive: Bool
    let isPerformingGroupAction: Bool
    let primaryActionTitle: String
    let primaryActionSystemImage: String
    let onPrimaryAction: () -> Void
    let onShareAction: (() -> Void)?
    let destructiveActionTitle: String?
    let destructiveActionSystemImage: String?
    let onDestructiveAction: (() -> Void)?

    var body: some View {
        GroupSettingsCardContainer(isHighlighted: isActive) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)

                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text(detailText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    GroupSettingsBadgeView(text: badgeText)
                }

                HStack(spacing: 10) {
                    primaryButton

                    Spacer(minLength: 0)

                    if let onShareAction {
                        Button(action: onShareAction) {
                            Image(systemName: "person.2.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingGroupAction)
                        .accessibilityLabel("Gruppe teilen")
                    }

                    if let destructiveActionTitle,
                       let destructiveActionSystemImage,
                       let onDestructiveAction {
                        Menu {
                            Button(role: .destructive, action: onDestructiveAction) {
                                Label(destructiveActionTitle, systemImage: destructiveActionSystemImage)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPerformingGroupAction)
                        .accessibilityLabel("Weitere Optionen")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if isActive {
            Button("Aktiv") {}
                .buttonStyle(.bordered)
                .disabled(true)
        } else {
            Button(action: onPrimaryAction) {
                Label(primaryActionTitle, systemImage: primaryActionSystemImage)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPerformingGroupAction)
        }
    }
}

struct GroupSettingsCreateGroupCardView: View {
    @Binding var newCloudGroupName: String
    let isDisabled: Bool
    let onCreateGroup: () -> Void

    private var trimmedGroupName: String {
        newCloudGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        GroupSettingsCardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("Erstelle eine eigene Cloud-Gruppe, um Listen, Mitglieder und Aktivitäten mit anderen zu teilen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Name der Gruppe", text: $newCloudGroupName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !trimmedGroupName.isEmpty, !isDisabled else { return }
                        onCreateGroup()
                    }

                Button(action: onCreateGroup) {
                    Label("Neue Gruppe erstellen", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedGroupName.isEmpty || isDisabled)
            }
        }
    }
}

struct GroupSettingsEmptyStateCardView: View {
    let message: String

    var body: some View {
        GroupSettingsCardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label("Noch keine Cloud-Gruppen", systemImage: "icloud.slash")
                    .font(.headline)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GroupSettingsBadgeView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(displaySettings.tintColor.opacity(0.12))
            .foregroundStyle(displaySettings.tintColor)
            .clipShape(Capsule())
    }
}
