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

    @Test func identicalInputsDoNotStartAnotherSnapshotBuild() async {
        let counter = BuildCallCounter()
        let movie = makeMovie(title: "Only")
        let snapshot = ContentMovieItemsSnapshot(
            watchedItems: [ContentMovieItem(movie: movie)],
            backlogItems: []
        )
        let model = ContentMovieItemsModel(
            snapshotBuilder: { _, _ in
                counter.increment()
                return snapshot
            }
        )
        let inputs = makeInputs(watchedMovies: [movie])

        let firstUpdateStarted = model.update(inputs)
        let secondUpdateStarted = model.update(inputs)

        await waitForUpdates(count: 3)

        #expect(firstUpdateStarted)
        #expect(!secondUpdateStarted)
        #expect(counter.value == 1)
        #expect(model.watchedItems.map(\.movieId) == [movie.id])
    }

    @Test func relevantInputChangeStartsAnotherSnapshotBuild() async {
        let counter = BuildCallCounter()
        let movie = makeMovie(title: "Only")
        let model = ContentMovieItemsModel(
            snapshotBuilder: { inputs, _ in
                counter.increment()
                return ContentMovieItemsSnapshot(
                    watchedItems: inputs.watchedMovies.map { ContentMovieItem(movie: $0) },
                    backlogItems: []
                )
            }
        )

        let firstUpdateStarted = model.update(makeInputs(watchedMovies: [movie], watchedSearchText: "only"))

        await waitForUpdates(count: 3)

        let secondUpdateStarted = model.update(makeInputs(watchedMovies: [movie], watchedSearchText: "other"))

        await waitForUpdates(count: 3)

        #expect(firstUpdateStarted)
        #expect(secondUpdateStarted)
        #expect(counter.value == 2)
    }

    @Test func movieContentChangeUpdatesInputSignature() {
        let movieId = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let original = makeMovie(id: movieId, title: "Original")
        let renamed = makeMovie(id: movieId, title: "Renamed")

        let originalSignature = ContentMovieItemsInputSignature(
            inputs: makeInputs(watchedMovies: [original])
        )
        let renamedSignature = ContentMovieItemsInputSignature(
            inputs: makeInputs(watchedMovies: [renamed])
        )

        #expect(originalSignature != renamedSignature)
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
        id: UUID = UUID(),
        title: String,
        watchedDate: Date? = nil,
        suggestedBy: String? = nil
    ) -> Movie {
        Movie(
            id: id,
            title: title,
            year: "2026",
            watchedDate: watchedDate,
            suggestedBy: suggestedBy
        )
    }

    private func makeInputs(
        watchedMovies: [Movie] = [],
        backlogMovies: [Movie] = [],
        watchedSearchText: String = "",
        backlogSearchText: String = "",
        filterByUser: User? = nil,
        sort: MovieSortOption = .dateNewest,
        ratingDisplayMode: RatingDisplayMode = .ratingAverage,
        showTMDbRatingsInLists: Bool = false
    ) -> ContentMovieItemsModel.Inputs {
        ContentMovieItemsModel.Inputs(
            watchedMovies: watchedMovies,
            backlogMovies: backlogMovies,
            watchedSearchText: watchedSearchText,
            backlogSearchText: backlogSearchText,
            filterByUser: filterByUser,
            sort: sort,
            ratingDisplayMode: ratingDisplayMode,
            showTMDbRatingsInLists: showTMDbRatingsInLists
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

private final class BuildCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
