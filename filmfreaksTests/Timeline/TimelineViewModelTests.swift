import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct TimelineViewModelTests {

    @Test func updateMoviesBuildsSnapshotWithCurrentInputs() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ]

        var capturedMovies: [Movie] = []
        var capturedFilterMode: TimelineFilterMode?
        var capturedSelectedRange: TimelineTimeRange?
        var capturedSelectedYear: Int?

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
                capturedMovies = movies
                capturedFilterMode = filterMode
                capturedSelectedRange = selectedRange
                capturedSelectedYear = selectedYear
                return expectedSnapshot
            }
        )

        viewModel.updateMovies(movies)

        #expect(capturedMovies == movies)
        #expect(capturedFilterMode == .year)
        #expect(capturedSelectedRange == .thisYear)
        #expect(capturedSelectedYear == 2026)
        #expect(viewModel.snapshot == expectedSnapshot)
    }

    @Test func updateMoviesDeduplicatesUnchangedInputsWithinSameDay() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ]

        var buildCount = 0

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2026,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { _, _, _, _, _, _ in
                buildCount += 1
                return TimelineSnapshot()
            }
        )

        viewModel.updateMovies(movies)
        viewModel.updateMovies(movies)

        #expect(buildCount == 1)
    }

    @Test func changingFilterInputTriggersRebuild() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar))
        ]

        var buildCount = 0

        let viewModel = TimelineViewModel(
            initialSelectedYear: 2026,
            calendar: calendar,
            todayProvider: { today },
            snapshotBuilder: { _, _, _, _, _, _ in
                buildCount += 1
                return TimelineSnapshot()
            }
        )

        viewModel.updateMovies(movies)
        viewModel.setSelectedRange(.last30)
        viewModel.setFilterMode(.range)

        #expect(buildCount == 3)
    }

    @Test func invalidSelectedYearFallsBackToFirstAvailableYear() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2025, month: 12, day: 20, calendar: calendar))
        ]

        var requestedYears: [Int] = []

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

        #expect(requestedYears == [2024, 2026])
        #expect(viewModel.selectedYear == 2026)
        #expect(viewModel.snapshot.availableYears == [2026, 2025])
        #expect(viewModel.snapshot.filteredMovies.isEmpty)
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
}
