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
                NavigationLink {
                    MovieDetailView(
                        movie: movieBinding(forIndex: item.index),
                        isBacklog: isBacklog
                    )
                } label: {
                    let average = displayScore(item.movie)
                    if selectedViewStyle == .compactList {
                        ContentCompactMovieRowView(movie: item.movie, average: average)
                    } else {
                        ContentMovieRowView(movie: item.movie, average: average)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(displaySettings.cardStyle == .cards ? .hidden : .automatic)
            }
            .onDelete(perform: delete)
        }
    }

    private func movieBinding(forIndex index: Int) -> Binding<Movie> {
        Binding<Movie>(
            get: { movies[index] },
            set: { movies[index] = $0 }
        )
    }

    private func delete(_ indexSet: IndexSet) {
        var originalIndices = IndexSet()
        for displayedIndex in indexSet {
            guard items.indices.contains(displayedIndex) else { continue }
            originalIndices.insert(items[displayedIndex].index)
        }
        movies.remove(atOffsets: originalIndices)
    }
}
