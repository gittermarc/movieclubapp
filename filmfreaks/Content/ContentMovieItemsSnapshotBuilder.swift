//
//  ContentMovieItemsSnapshotBuilder.swift
//  filmfreaks
//
//  Created on 08.04.26.
//

import Foundation

nonisolated struct ContentMovieItemsSnapshot: Sendable {
    let watchedItems: [IndexedMovie]
    let backlogItems: [IndexedMovie]
}

nonisolated enum ContentMovieItemsSnapshotBuilder {

    nonisolated struct Input: Sendable {
        let watchedMovies: [Movie]
        let backlogMovies: [Movie]
        let watchedSearchText: String
        let backlogSearchText: String
        let filterByUser: User?
        let sort: MovieSortOption
        let ratingDisplayMode: RatingDisplayMode
        let showTMDbRatingsInLists: Bool
    }

    static func build(
        input: Input,
        searchIndex: MovieSearchIndexCache
    ) -> ContentMovieItemsSnapshot {
        let watchedTokens = searchIndex.normalizedTokens(for: input.watchedSearchText)
        let backlogTokens = searchIndex.normalizedTokens(for: input.backlogSearchText)

        return ContentMovieItemsSnapshot(
            watchedItems: buildIndexedItems(
                from: input.watchedMovies,
                isBacklog: false,
                filterByUser: input.filterByUser,
                tokens: watchedTokens,
                sort: input.sort,
                ratingDisplayMode: input.ratingDisplayMode,
                showTMDbRatingsInLists: input.showTMDbRatingsInLists,
                searchIndex: searchIndex
            ),
            backlogItems: buildIndexedItems(
                from: input.backlogMovies,
                isBacklog: true,
                filterByUser: input.filterByUser,
                tokens: backlogTokens,
                sort: input.sort,
                ratingDisplayMode: input.ratingDisplayMode,
                showTMDbRatingsInLists: input.showTMDbRatingsInLists,
                searchIndex: searchIndex
            )
        )
    }

    private static func buildIndexedItems(
        from movies: [Movie],
        isBacklog: Bool,
        filterByUser: User?,
        tokens: [String],
        sort: MovieSortOption,
        ratingDisplayMode: RatingDisplayMode,
        showTMDbRatingsInLists: Bool,
        searchIndex: MovieSearchIndexCache
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

    private static func displayScore(
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

    private static func sortIsOrderedBefore(
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
                return lhs.year > rhs.year
            } else {
                let l = lhs.watchedDate ?? .distantPast
                let r = rhs.watchedDate ?? .distantPast
                return l > r
            }

        case .dateOldest:
            if isBacklog {
                return lhs.year < rhs.year
            } else {
                let l = lhs.watchedDate ?? .distantFuture
                let r = rhs.watchedDate ?? .distantFuture
                return l < r
            }
        }
    }

    private static func passesUserFilterForWatched(_ movie: Movie, user: User?) -> Bool {
        guard let user else { return true }
        return movie.ratings.contains { rating in
            if let rid = rating.reviewerId {
                return rid == user.id
            }
            return rating.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(user.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    private static func passesUserFilterForBacklog(_ movie: Movie, user: User?) -> Bool {
        guard let user else { return true }
        guard let sugg = movie.suggestedBy else { return false }
        return sugg.lowercased() == user.name.lowercased()
    }
}
