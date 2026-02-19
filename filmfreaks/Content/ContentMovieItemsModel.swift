//
//  ContentMovieItemsModel.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

internal import SwiftUI
import Combine

/// Computes the derived movie lists (filtered + searched + sorted) outside
/// of the SwiftUI render path.
///
/// The goal is that `ContentView.body` only reads `watchedItems/backlogItems`
/// instead of rebuilding them via `filter/sort/map` on every re-render.
@MainActor
final class ContentMovieItemsModel: ObservableObject {

    @Published private(set) var watchedItems: [IndexedMovie] = []
    @Published private(set) var backlogItems: [IndexedMovie] = []

    let searchIndex = MovieSearchIndexCache()

    func update(
        watchedMovies: [Movie],
        backlogMovies: [Movie],
        watchedSearchText: String,
        backlogSearchText: String,
        filterByUser: User?,
        sort: MovieSortOption,
        ratingDisplayMode: RatingDisplayMode,
        showTMDbRatingsInLists: Bool
    ) {
        let watchedTokens = searchIndex.normalizedTokens(for: watchedSearchText)
        let backlogTokens = searchIndex.normalizedTokens(for: backlogSearchText)

        self.watchedItems = buildIndexedItems(
            from: watchedMovies,
            isBacklog: false,
            filterByUser: filterByUser,
            tokens: watchedTokens,
            sort: sort,
            ratingDisplayMode: ratingDisplayMode,
            showTMDbRatingsInLists: showTMDbRatingsInLists
        )

        self.backlogItems = buildIndexedItems(
            from: backlogMovies,
            isBacklog: true,
            filterByUser: filterByUser,
            tokens: backlogTokens,
            sort: sort,
            ratingDisplayMode: ratingDisplayMode,
            showTMDbRatingsInLists: showTMDbRatingsInLists
        )
    }

    // MARK: - Build

    private func buildIndexedItems(
        from movies: [Movie],
        isBacklog: Bool,
        filterByUser: User?,
        tokens: [String],
        sort: MovieSortOption,
        ratingDisplayMode: RatingDisplayMode,
        showTMDbRatingsInLists: Bool
    ) -> [IndexedMovie] {
        let enumerated = Array(movies.enumerated())
            .filter { _, movie in
                if isBacklog {
                    return passesUserFilterForBacklog(movie, user: filterByUser)
                        && searchIndex.matches(movie: movie, tokens: tokens)
                } else {
                    return passesUserFilterForWatched(movie, user: filterByUser)
                        && searchIndex.matches(movie: movie, tokens: tokens)
                }
            }

        let sorted = enumerated.sorted { lhs, rhs in
            sortIsOrderedBefore(
                lhs.element,
                rhs.element,
                isBacklog: isBacklog,
                sort: sort,
                ratingDisplayMode: ratingDisplayMode,
                showTMDbRatingsInLists: showTMDbRatingsInLists
            )
        }

        return sorted.map { IndexedMovie(index: $0.offset, movie: $0.element) }
    }

    // MARK: - Sorting

    private func displayScore(
        for movie: Movie,
        mode: RatingDisplayMode,
        showTMDbRatingsInLists: Bool
    ) -> Double? {
        if showTMDbRatingsInLists {
            return movie.displayAverage(for: mode)
        } else {
            return movie.groupAverage(for: mode)
        }
    }

    private func sortIsOrderedBefore(
        _ lhs: Movie,
        _ rhs: Movie,
        isBacklog: Bool,
        sort: MovieSortOption,
        ratingDisplayMode: RatingDisplayMode,
        showTMDbRatingsInLists: Bool
    ) -> Bool {
        switch sort {
        case .titleAZ:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending

        case .titleZA:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending

        case .ratingHigh:
            let l = displayScore(for: lhs, mode: ratingDisplayMode, showTMDbRatingsInLists: showTMDbRatingsInLists) ?? -Double.infinity
            let r = displayScore(for: rhs, mode: ratingDisplayMode, showTMDbRatingsInLists: showTMDbRatingsInLists) ?? -Double.infinity
            return l > r

        case .ratingLow:
            let l = displayScore(for: lhs, mode: ratingDisplayMode, showTMDbRatingsInLists: showTMDbRatingsInLists) ?? Double.infinity
            let r = displayScore(for: rhs, mode: ratingDisplayMode, showTMDbRatingsInLists: showTMDbRatingsInLists) ?? Double.infinity
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

    // MARK: - User Filter

    private func passesUserFilterForWatched(_ movie: Movie, user: User?) -> Bool {
        guard let user else { return true }
        return movie.ratings.contains { rating in
            if let rid = rating.reviewerId {
                return rid == user.id
            }
            // Legacy/local fallback: compare by display name
            return rating.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(user.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    private func passesUserFilterForBacklog(_ movie: Movie, user: User?) -> Bool {
        guard let user else { return true }
        guard let sugg = movie.suggestedBy else { return false }
        return sugg.lowercased() == user.name.lowercased()
    }
}
