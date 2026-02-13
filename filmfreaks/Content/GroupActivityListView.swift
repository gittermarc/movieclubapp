//
//  GroupActivityListView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

struct GroupActivityListView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    private var groupId: String {
        (movieStore.currentGroupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var movieEvents: [GroupActivityEvent] {
        movieStore.activityEvents(displayMode: displaySettings.ratingDisplayMode)
    }

    private var nightEvents: [MovieNightActivityEvent] {
        movieNightStore.activityEvents(for: groupId)
    }

    private var unifiedEvents: [UnifiedGroupActivityEvent] {
        let movies = movieEvents.map { UnifiedGroupActivityEvent(movieEvent: $0) }
        let nights = nightEvents.map { UnifiedGroupActivityEvent(movieNightActivity: $0) }
        return (movies + nights).sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationStack {
            Group {
                if unifiedEvents.isEmpty {
                    ContentUnavailableView(
                        "Keine Aktivität",
                        systemImage: "sparkles",
                        description: Text("Wenn in der Gruppe was passiert, siehst du es hier.")
                    )
                } else {
                    List {
                        ForEach(unifiedEvents) { e in
                            UnifiedGroupActivityRowView(event: e)
                                .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Aktivität")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}
