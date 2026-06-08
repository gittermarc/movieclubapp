//
//  ContentMoviesListSection.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Wiederverwendbarer Listen-Block für „Gesehen“ und „Backlog“.
///
/// Erwartet bereits gefilterte + sortierte Items mit stabiler Movie-ID.
/// Navigation, Binding und Delete werden gegen die aktuelle Source-Liste aufgelöst.
struct ContentMoviesListSection: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let items: [ContentMovieItem]
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
                    if let movie = sourceMovie(for: item) {
                        NavigationLink {
                            MovieDetailView(
                                movie: movieBinding(for: item),
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

    private func sourceMovie(for item: ContentMovieItem) -> Movie? {
        ContentMovieSourceLookup.movie(in: movies, matching: item)
    }

    private func movieBinding(for item: ContentMovieItem) -> Binding<Movie> {
        Binding(
            get: {
                sourceMovie(for: item) ?? item.movie
            },
            set: { updatedMovie in
                guard let sourceIndex = movies.firstIndex(where: { $0.id == item.movieId }) else { return }
                movies[sourceIndex] = updatedMovie
            }
        )
    }

    private func requestDelete(_ indexSet: IndexSet) {
        pendingDelete = ContentMovieSourceLookup.deleteConfirmation(
            for: indexSet,
            items: items,
            movies: movies,
            isBacklog: isBacklog
        )
    }

    private func confirmDelete(_ pending: MovieDeleteConfirmation) {
        let ids = Set(pending.movieIds)
        movies.removeAll { ids.contains($0.id) }
        pendingDelete = nil
    }
}
