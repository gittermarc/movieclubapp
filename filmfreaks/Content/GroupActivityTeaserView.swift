//
//  GroupActivityTeaserView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

/// Compact activity preview shown directly under the GroupContextBar.
struct GroupActivityTeaserView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let events: [GroupActivityEvent]
    let onOpenAll: () -> Void

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if events.isEmpty {
                emptyState
            } else {
                ForEach(events.prefix(3)) { e in
                    GroupActivityRowView(event: e)
                    if e.id != events.prefix(3).last?.id {
                        Divider().opacity(0.6)
                    }
                }
            }
        }
        .padding(m.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Zuletzt passiert", systemImage: "sparkles")
                .font(.headline)
                .symbolRenderingMode(.hierarchical)

            Spacer(minLength: 8)

            Button(action: onOpenAll) {
                HStack(spacing: 4) {
                    Text("Alle")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(displaySettings.tintColor)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Noch keine Gruppenaktivität")
                    .font(.subheadline.weight(.semibold))
                Text("Sobald jemand einen Film hinzufügt oder bewertet, taucht es hier auf.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
