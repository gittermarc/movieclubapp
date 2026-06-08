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
    private var lastInputSignature: ContentMovieItemsInputSignature?

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

    @discardableResult
    func update(_ inputs: Inputs) -> Bool {
        let signature = ContentMovieItemsInputSignature(inputs: inputs)
        guard signature != lastInputSignature else {
            return false
        }

        lastInputSignature = signature
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

        return true
    }

    private func apply(snapshot: Snapshot, for generation: Int) {
        guard buildGeneration == generation else { return }
        watchedItems = snapshot.watchedItems
        backlogItems = snapshot.backlogItems
    }
}

nonisolated struct ContentMovieItemsInputSignature: Equatable {
    private let watchedMovies: [ContentMovieItemsMovieSignature]
    private let backlogMovies: [ContentMovieItemsMovieSignature]
    private let watchedSearchText: String
    private let backlogSearchText: String
    private let filterUserId: UUID?
    private let filterUserName: String?
    private let sort: MovieSortOption
    private let ratingDisplayMode: RatingDisplayMode
    private let showTMDbRatingsInLists: Bool

    init(inputs: ContentMovieItemsModel.Inputs) {
        self.watchedMovies = inputs.watchedMovies.map(ContentMovieItemsMovieSignature.init)
        self.backlogMovies = inputs.backlogMovies.map(ContentMovieItemsMovieSignature.init)
        self.watchedSearchText = inputs.watchedSearchText
        self.backlogSearchText = inputs.backlogSearchText
        self.filterUserId = inputs.filterByUser?.id
        self.filterUserName = inputs.filterByUser?.name
        self.sort = inputs.sort
        self.ratingDisplayMode = inputs.ratingDisplayMode
        self.showTMDbRatingsInLists = inputs.showTMDbRatingsInLists
    }
}

nonisolated private struct ContentMovieItemsMovieSignature: Equatable {
    let id: UUID
    let title: String
    let year: String
    let tmdbRating: Double?
    let ratings: [ContentMovieItemsRatingSignature]
    let posterPath: String?
    let watchedDate: Date?
    let watchedLocation: String?
    let suggestedBy: String?
    let cast: [ContentMovieItemsPersonSignature]
    let directors: [ContentMovieItemsPersonSignature]
    let genres: [String]
    let keywords: [String]

    init(movie: Movie) {
        self.id = movie.id
        self.title = movie.title
        self.year = movie.year
        self.tmdbRating = movie.tmdbRating
        self.ratings = movie.ratings.map(ContentMovieItemsRatingSignature.init)
        self.posterPath = movie.posterPath
        self.watchedDate = movie.watchedDate
        self.watchedLocation = movie.watchedLocation
        self.suggestedBy = movie.suggestedBy
        self.cast = (movie.cast ?? []).map(ContentMovieItemsPersonSignature.init)
        self.directors = (movie.directors ?? []).map(ContentMovieItemsPersonSignature.init)
        self.genres = movie.genres ?? []
        self.keywords = movie.keywords ?? []
    }
}

nonisolated private struct ContentMovieItemsRatingSignature: Equatable {
    let reviewerId: UUID?
    let reviewerName: String
    let scores: [RatingCriterion: Int]
    let fazitScore: Int?

    init(rating: Rating) {
        self.reviewerId = rating.reviewerId
        self.reviewerName = rating.reviewerName
        self.scores = rating.scores
        self.fazitScore = rating.fazitScore
    }
}

nonisolated private struct ContentMovieItemsPersonSignature: Equatable {
    let personId: Int
    let name: String

    init(member: CastMember) {
        self.personId = member.personId
        self.name = member.name
    }
}
