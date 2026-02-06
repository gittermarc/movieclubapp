//
//  GroupActivityListView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

struct GroupActivityListView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    private var events: [GroupActivityEvent] {
        movieStore.activityEvents(displayMode: displaySettings.ratingDisplayMode)
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "Keine Aktivität",
                        systemImage: "sparkles",
                        description: Text("Wenn in der Gruppe was passiert, siehst du es hier.")
                    )
                } else {
                    List {
                        ForEach(events) { e in
                            GroupActivityRowView(event: e)
                                .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
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
