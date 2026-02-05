//
//  ContentView+MovieItems.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

extension ContentView {

    // MARK: - List/Grid Items (gefiltert + sortiert)

    private func sortIsOrderedBefore(_ lhs: Movie, _ rhs: Movie, isBacklog: Bool) -> Bool {
        switch selectedSort {
        case .titleAZ:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending

        case .titleZA:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending

        case .ratingHigh:
            let l = displayScore(for: lhs) ?? -Double.infinity
            let r = displayScore(for: rhs) ?? -Double.infinity
            return l > r

        case .ratingLow:
            let l = displayScore(for: lhs) ?? Double.infinity
            let r = displayScore(for: rhs) ?? Double.infinity
            return l < r

        case .dateNewest:
            if isBacklog {
                // Im Backlog: neuestes Erscheinungsjahr zuerst
                return lhs.year > rhs.year
            } else {
                let l = lhs.watchedDate ?? .distantPast
                let r = rhs.watchedDate ?? .distantPast
                return l > r
            }

        case .dateOldest:
            if isBacklog {
                // Im Backlog: ältestes Erscheinungsjahr zuerst
                return lhs.year < rhs.year
            } else {
                let l = lhs.watchedDate ?? .distantFuture
                let r = rhs.watchedDate ?? .distantFuture
                return l < r
            }
        }
    }

    private func buildIndexedItems(from movies: [Movie], isBacklog: Bool) -> [IndexedMovie] {
        let enumerated = Array(movies.enumerated())
            .filter { _, movie in
                if isBacklog {
                    return passesUserFilterForBacklog(movie) && passesListSearch(movie, isBacklog: true)
                } else {
                    return passesUserFilterForWatched(movie) && passesListSearch(movie, isBacklog: false)
                }
            }

        let sorted = enumerated.sorted { lhs, rhs in
            sortIsOrderedBefore(lhs.element, rhs.element, isBacklog: isBacklog)
        }

        return sorted.map { IndexedMovie(index: $0.offset, movie: $0.element) }
    }

    private var watchedItems: [IndexedMovie] {
        buildIndexedItems(from: movieStore.movies, isBacklog: false)
    }

    private var backlogItems: [IndexedMovie] {
        buildIndexedItems(from: movieStore.backlogMovies, isBacklog: true)
    }

    /// Grid: Gesehen
    var watchedGridItems: [IndexedMovie] { watchedItems }

    /// Grid: Backlog
    var backlogGridItems: [IndexedMovie] { backlogItems }

    /// Liste: Gesehen
    var watchedListItems: [IndexedMovie] { watchedItems }

    /// Liste: Backlog
    var backlogListItems: [IndexedMovie] { backlogItems }
}
