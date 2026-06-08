//
//  ContentMovieSourceLookup.swift
//  filmfreaks
//
//  Small ID-based lookup helpers for Content list/grid snapshots.
//

import Foundation

nonisolated enum ContentMovieSourceLookup {

    static func movie(
        in movies: [Movie],
        matching item: ContentMovieItem
    ) -> Movie? {
        movies.first { $0.id == item.movieId }
    }

    static func deleteConfirmation(
        for displayedOffsets: IndexSet,
        items: [ContentMovieItem],
        movies: [Movie],
        isBacklog: Bool
    ) -> MovieDeleteConfirmation? {
        var ids: [UUID] = []
        var titles: [String] = []
        var seenIds = Set<UUID>()

        for displayedIndex in displayedOffsets.sorted() {
            guard items.indices.contains(displayedIndex) else { continue }
            let item = items[displayedIndex]
            guard !seenIds.contains(item.movieId) else { continue }
            guard let movie = movie(in: movies, matching: item) else { continue }

            ids.append(item.movieId)
            titles.append(movie.title)
            seenIds.insert(item.movieId)
        }

        guard !ids.isEmpty else { return nil }
        return MovieDeleteConfirmation(
            movieIds: ids,
            movieTitles: titles,
            isBacklog: isBacklog
        )
    }
}
