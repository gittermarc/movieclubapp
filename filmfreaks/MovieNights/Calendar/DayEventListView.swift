//
//  DayEventListView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Read-only list of all movie nights for a specific day.
struct DayEventListView: View {

    let day: Date
    let groupId: String
    let events: [MovieNightEvent]

    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    private var dayTitle: String {
        Self.dayTitleFormatter.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(dayTitle)
                    .font(.headline)

                Spacer(minLength: 10)

                if events.count > 0 {
                    Text(events.count == 1 ? "1 Eintrag" : "\(events.count) Einträge")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .circular)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
            }

            if events.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        MovieNightEventRow(
                            event: event,
                            responses: movieNightStore.responses(for: groupId, eventId: event.id)
                        )
                        .padding(.vertical, 10)

                        if event.id != events.last?.id {
                            Divider().opacity(0.6)
                        }
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

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "popcorn")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Keine Filmabende")
                    .font(.subheadline.weight(.semibold))
                Text("Für diesen Tag ist noch nichts geplant.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private static let dayTitleFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE, d. MMM")
        return df
    }()
}
