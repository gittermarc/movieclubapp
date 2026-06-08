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

    typealias Snapshot = ContentMovieItemsSnapshot
    typealias SnapshotBuilder = @Sendable (Inputs, MovieSearchIndexCache) -> Snapshot

    struct Inputs: Sendable {
        let watchedMovies: [Movie]
        let backlogMovies: [Movie]
        let watchedSearchText: String
        let backlogSearchText: String
        let filterByUser: User?
        let sort: MovieSortOption
        let ratingDisplayMode: RatingDisplayMode
        let showTMDbRatingsInLists: Bool
    }

    @Published private(set) var watchedItems: [ContentMovieItem] = []
    @Published private(set) var backlogItems: [ContentMovieItem] = []

    let searchIndex: MovieSearchIndexCache

    private let snapshotBuilder: SnapshotBuilder

    private var updateTask: Task<Void, Never>?
    private var buildGeneration: Int = 0

    init(
        searchIndex: MovieSearchIndexCache = MovieSearchIndexCache(),
        snapshotBuilder: SnapshotBuilder? = nil
    ) {
        self.searchIndex = searchIndex
        self.snapshotBuilder = snapshotBuilder ?? { inputs, searchIndex in
            ContentMovieItemsSnapshotBuilder.build(
                input: .init(
                    watchedMovies: inputs.watchedMovies,
                    backlogMovies: inputs.backlogMovies,
                    watchedSearchText: inputs.watchedSearchText,
                    backlogSearchText: inputs.backlogSearchText,
                    filterByUser: inputs.filterByUser,
                    sort: inputs.sort,
                    ratingDisplayMode: inputs.ratingDisplayMode,
                    showTMDbRatingsInLists: inputs.showTMDbRatingsInLists
                ),
                searchIndex: searchIndex
            )
        }
    }


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
        update(
            Inputs(
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies,
                watchedSearchText: watchedSearchText,
                backlogSearchText: backlogSearchText,
                filterByUser: filterByUser,
                sort: sort,
                ratingDisplayMode: ratingDisplayMode,
                showTMDbRatingsInLists: showTMDbRatingsInLists
            )
        )
    }

    func update(_ inputs: Inputs) {
        buildGeneration += 1
        let generation = buildGeneration
        let snapshotBuilder = self.snapshotBuilder
        let searchIndex = self.searchIndex

        updateTask?.cancel()
        updateTask = Task { [inputs, generation, snapshotBuilder, searchIndex] in
            guard !Task.isCancelled else { return }

            let snapshot = await Task.detached(priority: .userInitiated) {
                snapshotBuilder(inputs, searchIndex)
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.apply(snapshot: snapshot, for: generation)
            }
        }
    }

    private func apply(snapshot: Snapshot, for generation: Int) {
        guard buildGeneration == generation else { return }
        watchedItems = snapshot.watchedItems
        backlogItems = snapshot.backlogItems
    }
}
