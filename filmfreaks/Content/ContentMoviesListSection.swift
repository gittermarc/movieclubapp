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

    var body: some View {
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
            .onDelete(perform: delete)
        }
    }

    private func delete(_ indexSet: IndexSet) {
        var originalIndices = IndexSet()
        for displayedIndex in indexSet {
            guard items.indices.contains(displayedIndex) else { continue }
            let originalIndex = items[displayedIndex].index
            guard movies.indices.contains(originalIndex) else { continue }
            originalIndices.insert(originalIndex)
        }
        movies.remove(atOffsets: originalIndices)
    }
}
