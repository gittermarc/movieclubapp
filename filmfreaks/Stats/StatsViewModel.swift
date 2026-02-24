//
//  StatsViewModel.swift
//  filmfreaks
//
//  Cached aggregation model for StatsView.
//

import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {

    struct UserStats: Equatable {
        var movieCount: Int
        var ratingsCount: Int
        var averageRating: Double?
    }

    /// Cached, render-ready aggregation results.
    ///
    /// Note: Intentionally **not** `Equatable`.
    /// Several contained types (e.g. domain models / highlight structs) are not equatable,
    /// and SwiftUI does not require `Equatable` for `@Published` outputs.
    struct Snapshot {
        var moviesForCurrentTimeRange: [Movie]
        var filteredMovies: [Movie]
        var availableLocations: [String]

        var totalRatingsCount: Int
        var activeReviewersCount: Int
        var ratedMoviesCount: Int
        var ratingCoveragePercentText: String

        var memberKeysSet: Set<String>
        var activeReviewerKeysSet: Set<String>
        var unratedMoviesCount: Int
        var moviesRatedByAllActiveMembersCount: Int
        var moviesRatedByAllMembersCount: Int

        var overallAverageRating: Double?
        var mostRecentWatchedDate: Date?
        var monthTrends: [StatsMonthTrend]
        var moviesPerMonth: [(date: Date, count: Int)]
        var topRatedHighlights: [MovieHighlight]
        var controversialHighlights: [MovieHighlight]
        var criticGapEntries: [CriticGapEntry]
        var criticGapGroupHigher: [CriticGapEntry]
        var criticGapGroupLower: [CriticGapEntry]

        var moviesByGenreRaw: [(genre: String, count: Int)]
        var actorsByCountRaw: [ActorEntry]
        var moviesByLocation: [(location: String, count: Int)]
        var suggestionsByUser: [(name: String, count: Int)]

        var userStatsByUserId: [UUID: UserStats]

        static let empty = Snapshot(
            moviesForCurrentTimeRange: [],
            filteredMovies: [],
            availableLocations: [],
            totalRatingsCount: 0,
            activeReviewersCount: 0,
            ratedMoviesCount: 0,
            ratingCoveragePercentText: "0%",
            memberKeysSet: [],
            activeReviewerKeysSet: [],
            unratedMoviesCount: 0,
            moviesRatedByAllActiveMembersCount: 0,
            moviesRatedByAllMembersCount: 0,
            overallAverageRating: nil,
            mostRecentWatchedDate: nil,
            monthTrends: [],
            moviesPerMonth: [],
            topRatedHighlights: [],
            controversialHighlights: [],
            criticGapEntries: [],
            criticGapGroupHigher: [],
            criticGapGroupLower: [],
            moviesByGenreRaw: [],
            actorsByCountRaw: [],
            moviesByLocation: [],
            suggestionsByUser: [],
            userStatsByUserId: [:]
        )
    }

    @Published private(set) var snapshot: Snapshot = .empty

    private let debounceInterval: TimeInterval = 0.2
    private var pendingWorkItem: DispatchWorkItem?
    private var buildGeneration: Int = 0

    private struct Inputs: Equatable {
        var movies: [Movie]
        var users: [User]
        var ratingDisplayMode: RatingDisplayMode
        var selectedRange: StatsTimeRange
        var selectedLocationFilter: String?
    }

    private var lastInputs: Inputs?

    func update(
        movies: [Movie],
        users: [User],
        ratingDisplayMode: RatingDisplayMode,
        selectedRange: StatsTimeRange,
        selectedLocationFilter: String?
    ) {
        let inputs = Inputs(
            movies: movies,
            users: users,
            ratingDisplayMode: ratingDisplayMode,
            selectedRange: selectedRange,
            selectedLocationFilter: selectedLocationFilter
        )

        if let lastInputs, lastInputs == inputs {
            return
        }
        lastInputs = inputs

        // Debounce and compute off-main to avoid UI stalls when multiple .onChange triggers fire.
        buildGeneration += 1
        let generation = buildGeneration

        pendingWorkItem?.cancel()

        var workItem: DispatchWorkItem?
        workItem = DispatchWorkItem { [inputs] in
            guard let workItem, !workItem.isCancelled else { return }

            let computed = StatsSnapshotBuilder.computeSnapshot(
                movies: inputs.movies,
                users: inputs.users,
                ratingDisplayMode: inputs.ratingDisplayMode,
                selectedRange: inputs.selectedRange,
                selectedLocationFilter: inputs.selectedLocationFilter
            )

            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.buildGeneration == generation else { return }
                guard !workItem.isCancelled else { return }
                self.snapshot = computed
            }
        }

        pendingWorkItem = workItem

        if let workItem {
            DispatchQueue.global(qos: .userInitiated)
                .asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
        }
    }
}
