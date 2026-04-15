//
//  GroupActivityStatusButton.swift
//  filmfreaks
//
//  Created on 15.04.26.
//

internal import SwiftUI

struct GroupActivityStatusButton: View {

    let tintColor: Color
    let newEventsCount: Int
    let action: () -> Void

    private var hasNewEvents: Bool {
        newEventsCount > 0
    }

    private var newEventsBadgeText: String {
        if newEventsCount > 9 {
            return "9+"
        }
        return String(newEventsCount)
    }

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                fullContent
                compactContent
                iconOnlyContent
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(hasNewEvents ? tintColor.opacity(0.12) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(hasNewEvents ? tintColor.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Öffnet die Gruppenaktivität")
    }

    private var fullContent: some View {
        HStack(spacing: 8) {
            statusIcon

            Text("Aktivität")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if hasNewEvents {
                badgeText
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var compactContent: some View {
        HStack(spacing: 8) {
            statusIcon

            if hasNewEvents {
                badgeText
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var iconOnlyContent: some View {
        statusIcon
            .overlay(alignment: .topTrailing) {
                if hasNewEvents {
                    Circle()
                        .fill(tintColor)
                        .frame(width: 8, height: 8)
                        .offset(x: 3, y: -3)
                        .accessibilityHidden(true)
                }
            }
            .fixedSize(horizontal: true, vertical: true)
    }

    private var statusIcon: some View {
        Image(systemName: hasNewEvents ? "sparkles" : "clock.arrow.circlepath")
            .font(.caption.weight(.semibold))
            .foregroundStyle(hasNewEvents ? tintColor : .secondary)
    }

    private var badgeText: some View {
        Text(newEventsBadgeText)
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tintColor.opacity(0.16))
            .foregroundStyle(tintColor)
            .clipShape(Capsule())
            .accessibilityLabel("\(newEventsCount) neue Aktivitäten")
    }

    private var accessibilityLabel: String {
        if hasNewEvents {
            return "Aktivität, \(newEventsCount) neue Einträge"
        }
        return "Aktivität"
    }
}
