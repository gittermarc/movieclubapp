//
//  ContentMoviesListSection.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Wiederverwendbarer Listen-Block für „Gesehen“ und „Backlog“.
///
/// Erwartet bereits gefilterte + sortierte Items (mit Original-Index in der Source-Array),
/// damit Delete korrekt in der Quelle landet.
struct ContentMoviesListSection: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let items: [IndexedMovie]
    @Binding var movies: [Movie]
    let isBacklog: Bool
    let selectedViewStyle: MovieViewStyle
    let query: String
    let displayScore: (Movie) -> Double?

    @State private var pendingDelete: MovieDeleteConfirmation?

    private var isPresentingDeleteAlert: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { newValue in
                if !newValue { pendingDelete = nil }
            }
        )
    }

    var body: some View {
        Group {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedQuery.isEmpty && items.isEmpty {
                ContentUnavailableView(
                    "Keine Treffer",
                    systemImage: "magnifyingglass",
                    description: Text("Passe den Suchbegriff an oder lösche ihn.")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(items) { item in
                    // When groups switch or a new empty group is created, SwiftUI can briefly render
                    // stale `items` while `movies` has already been cleared. Guard to prevent
                    // out-of-range crashes (movies[item.index]).
                    if movies.indices.contains(item.index) {
                        let movie = movies[item.index]

                        NavigationLink {
                            MovieDetailView(
                                movie: $movies[item.index],
                                isBacklog: isBacklog
                            )
                        } label: {
                            let average = displayScore(movie)
                            if selectedViewStyle == .compactList {
                                ContentCompactMovieRowView(movie: movie, average: average)
                            } else {
                                ContentMovieRowView(movie: movie, average: average)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(displaySettings.cardStyle == .cards ? .hidden : .automatic)
                    }
                }
                .onDelete(perform: requestDelete)
            }
        }
        .alert(
            pendingDelete?.alertTitle ?? "Film löschen?",
            isPresented: isPresentingDeleteAlert,
            presenting: pendingDelete
        ) { pending in
            Button("Löschen", role: .destructive) {
                confirmDelete(pending)
            }
            Button("Abbrechen", role: .cancel) {
                pendingDelete = nil
            }
        } message: { pending in
            Text(pending.alertMessage)
        }
    }

    private func requestDelete(_ indexSet: IndexSet) {
        // Convert the displayed indices into stable movie IDs.
        var ids: [UUID] = []
        var titles: [String] = []

        for displayedIndex in indexSet {
            guard items.indices.contains(displayedIndex) else { continue }
            let originalIndex = items[displayedIndex].index
            guard movies.indices.contains(originalIndex) else { continue }

            let movie = movies[originalIndex]
            ids.append(movie.id)
            titles.append(movie.title)
        }

        // Avoid empty alert (can happen when stale items render briefly during group switches).
        guard !ids.isEmpty else { return }

        // De-dupe just in case.
        let uniqueIds = Array(Set(ids))
        pendingDelete = MovieDeleteConfirmation(movieIds: uniqueIds, movieTitles: titles, isBacklog: isBacklog)
    }

    private func confirmDelete(_ pending: MovieDeleteConfirmation) {
        let ids = Set(pending.movieIds)
        movies.removeAll { ids.contains($0.id) }
        pendingDelete = nil
    }
}
