import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct TimelineViewModelTests {

    @Test func updateMoviesBuildsSnapshotWithCurrentInputs() async {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ]

        let recorder = TimelineBuilderInvocationRecorder()

        let expectedSnapshot = TimelineSnapshot(
            availableYears: [2026],
            filteredMovies: movies,
            monthGroups: []
        )

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2026,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { movies, filterMode, selectedRange, selectedYear, _, _ in
                recorder.record(
                    movies: movies,
                    filterMode: filterMode,
                    selectedRange: selectedRange,
                    selectedYear: selectedYear
                )
                return expectedSnapshot
            }
        )

        viewModel.updateMovies(movies)
        await waitForUpdates()

        let recorded = recorder.snapshot()
        #expect(recorded.movies == movies)
        #expect(recorded.filterMode == .year)
        #expect(recorded.selectedRange == .thisYear)
        #expect(recorded.selectedYear == 2026)
        #expect(viewModel.snapshot == expectedSnapshot)
    }

    @Test func updateMoviesDeduplicatesUnchangedInputsWithinSameDay() async {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ]

        let buildCounter = LockedIntBox()

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2026,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { _, _, _, _, _, _ in
                buildCounter.increment()
                return TimelineSnapshot()
            }
        )

        viewModel.updateMovies(movies)
        await waitForUpdates()
        viewModel.updateMovies(movies)
        await waitForUpdates()

        #expect(buildCounter.value == 1)
    }

    @Test func changingFilterInputTriggersRebuild() async {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ]

        let buildCounter = LockedIntBox()

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2026,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { _, _, _, _, _, _ in
                buildCounter.increment()
                return TimelineSnapshot()
            }
        )

        viewModel.updateMovies(movies)
        await waitForUpdates()
        viewModel.setSelectedRange(.last30)
        await waitForUpdates()
        viewModel.setFilterMode(.range)
        await waitForUpdates()

        #expect(buildCounter.value == 3)
    }

    @Test func invalidSelectedYearFallsBackToFirstAvailableYear() async {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2025, month: 12, day: 20, calendar: calendar))
        ]

        let requestedYears = LockedIntArrayBox()

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2024,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { movies, filterMode, selectedRange, selectedYear, today, calendar in
                requestedYears.append(selectedYear)
                return TimelineSnapshotBuilder.build(
                    movies: movies,
                    filterMode: filterMode,
                    selectedRange: selectedRange,
                    selectedYear: selectedYear,
                    today: today,
                    calendar: calendar
                )
            }
        )

        viewModel.updateMovies(movies)
        await waitForUpdates(count: 5)

        #expect(requestedYears.values == [2024, 2026])
        #expect(viewModel.selectedYear == 2026)
        #expect(viewModel.snapshot.availableYears == [2026, 2025])
        #expect(viewModel.snapshot.filteredMovies.isEmpty)
    }

    @Test func latestUpdateWinsWhenInputsChangeQuickly() async {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let oldSnapshot = TimelineSnapshot(
            availableYears: [2026],
            filteredMovies: [makeMovie(title: "Old", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))],
            monthGroups: []
        )
        let newSnapshot = TimelineSnapshot(
            availableYears: [2026],
            filteredMovies: [makeMovie(title: "New", watchedDate: makeDate(year: 2026, month: 4, day: 2, calendar: calendar))],
            monthGroups: []
        )

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2026,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { movies, _, _, _, _, _ in
                if movies.contains(where: { $0.title == "Old Source" }) {
                    Thread.sleep(forTimeInterval: 0.05)
                    return oldSnapshot
                }
                return newSnapshot
            }
        )

        viewModel.updateMovies([
            makeMovie(title: "Old Source", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ])
        viewModel.updateMovies([
            makeMovie(title: "New Source", watchedDate: makeDate(year: 2026, month: 4, day: 2, calendar: calendar))
        ])

        await waitForUpdates(count: 6)

        #expect(viewModel.snapshot.filteredMovies.map(\.title) == ["New"])
    }

    private func makeMovie(title: String, watchedDate: Date?) -> Movie {
        Movie(title: title, year: "2026", watchedDate: watchedDate)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
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

    private func waitForUpdates(count: Int = 4) async {
        for _ in 0..<count {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

private final class TimelineBuilderInvocationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMovies: [Movie] = []
    private var recordedFilterMode: TimelineFilterMode?
    private var recordedSelectedRange: TimelineTimeRange?
    private var recordedSelectedYear: Int?

    func record(
        movies: [Movie],
        filterMode: TimelineFilterMode,
        selectedRange: TimelineTimeRange,
        selectedYear: Int
    ) {
        lock.lock()
        recordedMovies = movies
        recordedFilterMode = filterMode
        recordedSelectedRange = selectedRange
        recordedSelectedYear = selectedYear
        lock.unlock()
    }

    func snapshot() -> (
        movies: [Movie],
        filterMode: TimelineFilterMode?,
        selectedRange: TimelineTimeRange?,
        selectedYear: Int?
    ) {
        lock.lock()
        defer { lock.unlock() }
        return (
            movies: recordedMovies,
            filterMode: recordedFilterMode,
            selectedRange: recordedSelectedRange,
            selectedYear: recordedSelectedYear
        )
    }
}

private final class LockedIntBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Int = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}

private final class LockedIntArrayBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int] = []

    var values: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ value: Int) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}
