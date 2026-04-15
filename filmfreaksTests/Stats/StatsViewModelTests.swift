import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct StatsViewModelTests {

    @Test func updateDeduplicatesUnchangedInputs() async {
        var buildCount = 0

        let viewModel = StatsViewModel(
            debounceNanos: 0,
            snapshotBuilder: { _ in
                buildCount += 1
                return .empty
            },
            actorSorter: { actors, _ in actors }
        )

        let inputs = makeInputs()
        viewModel.update(inputs)
        await waitForUpdates()

        viewModel.update(inputs)
        await waitForUpdates()

        #expect(buildCount == 1)
    }

    @Test func changingInputsTriggersAnotherBuild() async {
        var buildCount = 0

        let viewModel = StatsViewModel(
            debounceNanos: 0,
            snapshotBuilder: { _ in
                buildCount += 1
                return .empty
            },
            actorSorter: { actors, _ in actors }
        )

        viewModel.update(makeInputs(selectedRange: .all))
        await waitForUpdates()

        viewModel.update(makeInputs(selectedRange: .last30))
        await waitForUpdates()

        #expect(buildCount == 2)
    }

    @Test func latestUpdateWinsWhenInputsChangeQuickly() async {
        let firstSnapshot = StatsSnapshot(
            moviesForCurrentTimeRange: [makeMovie(title: "First", day: 1)],
            filteredMovies: [makeMovie(title: "First", day: 1)],
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
            tasteTwins: nil,
            frictionPair: nil,
            strictestReviewer: nil,
            mostGenerousReviewer: nil,
            hotTakeReviewer: nil,
            userStatsByUserId: [:]
        )
        let secondSnapshot = StatsSnapshot(
            moviesForCurrentTimeRange: [makeMovie(title: "Second", day: 2)],
            filteredMovies: [makeMovie(title: "Second", day: 2)],
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
            tasteTwins: nil,
            frictionPair: nil,
            strictestReviewer: nil,
            mostGenerousReviewer: nil,
            hotTakeReviewer: nil,
            userStatsByUserId: [:]
        )

        let viewModel = StatsViewModel(
            debounceNanos: 0,
            snapshotBuilder: { inputs in
                if inputs.selectedRange == .all {
                    Thread.sleep(forTimeInterval: 0.05)
                    return firstSnapshot
                }
                return secondSnapshot
            },
            actorSorter: { actors, _ in actors }
        )

        viewModel.update(makeInputs(selectedRange: .all))
        viewModel.update(makeInputs(selectedRange: .last30))
        await waitForUpdates(count: 6)

        #expect(viewModel.snapshot.filteredMovies.map(\.title) == ["Second"])
    }

    private func makeInputs(
        selectedRange: StatsTimeRange = .all,
        selectedLocationFilter: String? = nil,
        ratingDisplayMode: RatingDisplayMode = .ratingAverage
    ) -> StatsViewModel.Inputs {
        StatsViewModel.Inputs(
            movies: [makeMovie(title: "Arrival", day: 1, location: "Kino")],
            users: [User(name: "Marc")],
            ratingDisplayMode: ratingDisplayMode,
            selectedRange: selectedRange,
            selectedLocationFilter: selectedLocationFilter
        )
    }

    private func makeMovie(title: String, day: Int, location: String? = nil) -> Movie {
        Movie(
            title: title,
            year: "2026",
            watchedDate: makeDate(year: 2026, month: 4, day: day),
            watchedLocation: location
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }

    private func waitForUpdates(count: Int = 3) async {
        for _ in 0..<count {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
