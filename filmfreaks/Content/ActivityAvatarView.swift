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

    let name: String
    let badgeSystemImage: String?

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let first = (parts.first ?? "").prefix(1)
            let last = (parts.last ?? "").prefix(1)
            return String(first + last).uppercased()
        }
        if trimmed.isEmpty {
            return "??"
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if let badgeSystemImage {
                    badge(systemImage: badgeSystemImage)
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityLabel(name.isEmpty ? "Jemand" : name)
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
