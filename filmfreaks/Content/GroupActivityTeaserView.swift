//
//  GroupActivityTeaserView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

/// Compact activity preview shown directly under the GroupContextBar.
struct GroupActivityTeaserView: View {

    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    /// Default is collapsed to save vertical space.
    @AppStorage("groupActivityTeaserExpanded") private var isExpanded: Bool = false

    let events: [UnifiedGroupActivityEvent]
    let onOpenAll: () -> Void

    @State private var selectedMovieNight: MovieNightSheetSelection? = nil

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    private var visibleEvents: [UnifiedGroupActivityEvent] {
        let limit = isExpanded ? 3 : 1
        return Array(events.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if events.isEmpty {
                emptyState
            } else {
                ForEach(visibleEvents) { e in
                    UnifiedGroupActivityRowView(event: e, movieNightSelection: $selectedMovieNight)
                    if e.id != visibleEvents.last?.id {
                        Divider().opacity(0.6)
                    }
                }

                if !isExpanded, events.count > visibleEvents.count {
                    footerHint
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
        .sheet(item: $selectedMovieNight) { selection in
            MovieNightDetailSheet(groupId: selection.groupId, eventId: selection.id)
                .environmentObject(movieNightStore)
                .environmentObject(userStore)
                .environmentObject(displaySettings)
        }
        .animation(.snappy, value: isExpanded)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: toggleExpanded) {
                HStack(spacing: 8) {
                    Label("Zuletzt passiert", systemImage: "sparkles")
                        .font(.headline)
                        .symbolRenderingMode(.hierarchical)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Aktivitäten einklappen" : "Aktivitäten ausklappen")
            .accessibilityHint("Blendet die letzten Gruppenaktionen ein oder aus.")

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

    private var footerHint: some View {
        HStack(spacing: 8) {
            let remaining = max(0, events.count - visibleEvents.count)
            Text("Weitere \(remaining)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(action: toggleExpanded) {
                Text("Ausklappen")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(displaySettings.tintColor)
        }
        .padding(.top, 2)
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Noch keine Gruppenaktivität")
                    .font(.subheadline.weight(.semibold))
                Text("Sobald jemand einen Film bewertet, etwas hinzufügt oder einen Filmabend plant, taucht es hier auf.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func toggleExpanded() {
        isExpanded.toggle()
    }
}
