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

    var body: some View {
        NavigationStack {
            Group {
                if movieEvents.isEmpty && nightEvents.isEmpty {
                    ContentUnavailableView(
                        "Keine Aktivität",
                        systemImage: "sparkles",
                        description: Text("Wenn in der Gruppe was passiert, siehst du es hier.")
                    )
                } else {
                    List {
                        if !nightEvents.isEmpty {
                            Section {
                                ForEach(nightEvents) { e in
                                    MovieNightActivityRowView(event: e)
                                        .padding(.vertical, 4)
                                }
                            } header: {
                                Text("Filmabend-Planung")
                            }
                        }

                        if !movieEvents.isEmpty {
                            Section {
                                ForEach(movieEvents) { e in
                                    GroupActivityRowView(event: e)
                                        .padding(.vertical, 4)
                                }
                            } header: {
                                Text("Filme")
                            }
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
