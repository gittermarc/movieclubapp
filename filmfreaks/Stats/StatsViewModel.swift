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

    private let debounceNanos: UInt64 = 200_000_000
    private let actorsPopularitySortLimit: Int = 50
    private var updateTask: Task<Void, Never>?
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

        let debounceNanos = self.debounceNanos
        let actorsPopularitySortLimit = self.actorsPopularitySortLimit

        updateTask?.cancel()
        updateTask = Task { [inputs, debounceNanos, actorsPopularitySortLimit] in
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else { return }

            // 1) Base snapshot off-main.
            let base = await Task.detached(priority: .userInitiated) {
                StatsSnapshotBuilder.computeSnapshot(
                    movies: inputs.movies,
                    users: inputs.users,
                    ratingDisplayMode: inputs.ratingDisplayMode,
                    selectedRange: inputs.selectedRange,
                    selectedLocationFilter: inputs.selectedLocationFilter
                )
            }.value

            guard !Task.isCancelled else { return }

            // 2) Ensure popularity exists for the *final* visible top-actors BEFORE we publish.
            //    (Wichtig: wenn viele Darsteller die gleiche Häufigkeit haben, müssen wir die
            //    komplette "Schwellwert"-Gruppe laden – sonst ist das Top-50 Ergebnis falsch.)
            let ids: [Int] = {
                let actors = base.actorsByCountRaw
                guard !actors.isEmpty else { return [] }

                let limit = max(1, actorsPopularitySortLimit)
                if actors.count <= limit {
                    return actors.map { $0.personId }
                }

                let threshold = actors[limit - 1].count
                return actors
                    .filter { $0.count >= threshold }
                    .map { $0.personId }
            }()
            await PersonPopularityStore.shared.preloadPopularity(for: ids)

            guard !Task.isCancelled else { return }

            let popularity = PersonPopularityStore.shared.popularitySnapshot()

            // 3) Final actor order (count, then popularity, then name) off-main.
            let sortedActors = await Task.detached(priority: .userInitiated) {
                StatsSnapshotBuilder.sortActors(
                    actors: base.actorsByCountRaw,
                    popularityByPersonId: popularity
                )
            }.value

            var final = base
            final.actorsByCountRaw = sortedActors

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.buildGeneration == generation else { return }
                self.snapshot = final
            }
        }
    }
}
