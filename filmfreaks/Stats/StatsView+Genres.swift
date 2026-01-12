//
//  StatsView+Genres.swift
//  filmfreaks
//
//  Genre interaction + sheets for StatsView.
//

internal import SwiftUI

extension StatsView {

    // MARK: - Genre UI Stabilisierung

    func setGenreDisplayOrderNow() {
        let gen = UUID()
        genreSortGeneration = gen
        genreDisplayOrder = moviesByGenreRaw
    }

    func triggerGenreDisplayRecomputeDebounced() {
        let gen = UUID()
        genreSortGeneration = gen

        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                guard genreSortGeneration == gen else { return }
                genreDisplayOrder = moviesByGenreRaw
            }
        }
    }

    // MARK: - Genre Interaction

    func genreChipTapped(_ genre: String) {
        selectedGenreDrilldown = GenreDrilldown(genre: genre)
    }

    @ViewBuilder
    func genreMoviesSheet(for genre: String) -> some View {
        NavigationStack {
            List {
                let movies = filteredMovies.filter { movie in
                    (movie.genres ?? []).contains(where: { $0.lowercased() == genre.lowercased() })
                }

                if movies.isEmpty {
                    Text("Keine Filme für „\(genre)“ im aktuellen Filter.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(genre)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedGenreDrilldown = nil }
                }
            }
        }
    }
}
