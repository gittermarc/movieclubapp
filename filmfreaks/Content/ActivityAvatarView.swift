//
//  ActivityAvatarView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Shared avatar UI used across the unified group activity feed.
///
/// Shows initials and optionally a small badge (icon) in the bottom-right.
struct ActivityAvatarView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings
    @EnvironmentObject private var userStore: UserStore

    let name: String
    let badgeSystemImage: String?
    let memberId: UUID?

    init(
        name: String,
        badgeSystemImage: String?,
        memberId: UUID? = nil
    ) {
        self.name = name
        self.badgeSystemImage = badgeSystemImage
        self.memberId = memberId
    }

    var body: some View {
        MemberAvatarView(
            member: resolvedMember,
            fallbackName: name,
            groupId: userStore.currentGroupId,
            size: 34,
            tintColor: displaySettings.tintColor
        )
            .overlay(alignment: .bottomTrailing) {
                if let badgeSystemImage {
                    badge(systemImage: badgeSystemImage)
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityLabel(name.isEmpty ? "Jemand" : name)
    }

    private var resolvedMember: User? {
        MemberAvatarResolver.member(memberId: memberId, name: name, in: userStore.users)
    }

    private func badge(systemImage: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )

            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(displaySettings.tintColor)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
