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
        let snapshot = ContentMovieItemsSnapshotBuilder.build(
            input: .init(
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies,
                watchedSearchText: watchedSearchText,
                backlogSearchText: backlogSearchText,
                filterByUser: filterByUser,
                sort: sort,
                ratingDisplayMode: ratingDisplayMode,
                showTMDbRatingsInLists: showTMDbRatingsInLists
            ),
            searchIndex: searchIndex
        )

        watchedItems = snapshot.watchedItems
        backlogItems = snapshot.backlogItems
    }
}
