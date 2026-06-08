import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct ContentMovieItemsModelTests {

    @Test func latestUpdateWinsWhenInputsChangeQuickly() async {
        let firstSnapshot = ContentMovieItemsSnapshot(
            watchedItems: [ContentMovieItem(movie: makeMovie(title: "First"))],
            backlogItems: []
        )
        let secondSnapshot = ContentMovieItemsSnapshot(
            watchedItems: [ContentMovieItem(movie: makeMovie(title: "Second"))],
            backlogItems: []
        )

        let model = ContentMovieItemsModel(
            snapshotBuilder: { inputs, _ in
                if inputs.watchedSearchText == "old" {
                    Thread.sleep(forTimeInterval: 0.05)
                    return firstSnapshot
                }
                return secondSnapshot
            }
        )

        model.update(
            watchedMovies: [makeMovie(title: "Old Source")],
            backlogMovies: [],
            watchedSearchText: "old",
            backlogSearchText: "",
            filterByUser: nil,
            sort: .dateNewest,
            ratingDisplayMode: .ratingAverage,
            showTMDbRatingsInLists: false
        )

        model.update(
            watchedMovies: [makeMovie(title: "New Source")],
            backlogMovies: [],
            watchedSearchText: "new",
            backlogSearchText: "",
            filterByUser: nil,
            sort: .dateNewest,
            ratingDisplayMode: .ratingAverage,
            showTMDbRatingsInLists: false
        )

        await waitForUpdates(count: 6)

        #expect(model.watchedItems.map(\.movie.title) == ["Second"])
        #expect(model.backlogItems.isEmpty)
    }

    @Test func updatePublishesBuiltSnapshot() async {
        let model = ContentMovieItemsModel(
            snapshotBuilder: { inputs, cache in
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
                    searchIndex: cache
                )
            }
        )

        model.update(
            watchedMovies: [
                makeMovie(title: "Older", watchedDate: makeDate(year: 2024, month: 1, day: 1)),
                makeMovie(title: "Newer", watchedDate: makeDate(year: 2025, month: 1, day: 1))
            ],
            backlogMovies: [makeMovie(title: "Backlog", suggestedBy: "Marc")],
            watchedSearchText: "",
            backlogSearchText: "",
            filterByUser: nil,
            sort: .dateNewest,
            ratingDisplayMode: .ratingAverage,
            showTMDbRatingsInLists: false
        )

        await waitForUpdates(count: 4)

        #expect(model.watchedItems.map(\.movie.title) == ["Newer", "Older"])
        #expect(model.backlogItems.map(\.movie.title) == ["Backlog"])
    }

    private func makeMovie(
        title: String,
        watchedDate: Date? = nil,
        suggestedBy: String? = nil
    ) -> Movie {
        Movie(
            title: title,
            year: "2026",
            watchedDate: watchedDate,
            suggestedBy: suggestedBy
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
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
