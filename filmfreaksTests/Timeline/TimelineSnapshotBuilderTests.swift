import Foundation
import Testing
@testable import filmfreaks

struct TimelineSnapshotBuilderTests {

    @Test func availableYearsIncludesCurrentYearEvenWithoutWatchedMovies() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)

        let snapshot = TimelineSnapshotBuilder.build(
            movies: [makeMovie(title: "No Watch Date", watchedDate: nil)],
            filterMode: .year,
            selectedRange: .thisYear,
            selectedYear: 2026,
            today: today,
            calendar: calendar
        )

        #expect(snapshot.availableYears == [2026])
    }

    @Test func yearFilterReturnsOnlySelectedYearSortedNewestFirst() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)

        let snapshot = TimelineSnapshotBuilder.build(
            movies: [
                makeMovie(title: "2026 Earlier", watchedDate: makeDate(year: 2026, month: 1, day: 10, calendar: calendar)),
                makeMovie(title: "2025", watchedDate: makeDate(year: 2025, month: 12, day: 20, calendar: calendar)),
                makeMovie(title: "2026 Later", watchedDate: makeDate(year: 2026, month: 3, day: 5, calendar: calendar))
            ],
            filterMode: .year,
            selectedRange: .thisYear,
            selectedYear: 2026,
            today: today,
            calendar: calendar
        )

        #expect(snapshot.filteredMovies.map(\.title) == ["2026 Later", "2026 Earlier"])
    }

    @Test func rangeThisYearFiltersOnlyMoviesInsideCurrentYear() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)

        let snapshot = TimelineSnapshotBuilder.build(
            movies: [
                makeMovie(title: "Current Year", watchedDate: makeDate(year: 2026, month: 2, day: 14, calendar: calendar)),
                makeMovie(title: "Previous Year", watchedDate: makeDate(year: 2025, month: 12, day: 31, calendar: calendar))
            ],
            filterMode: .range,
            selectedRange: .thisYear,
            selectedYear: 2026,
            today: today,
            calendar: calendar
        )

        #expect(snapshot.filteredMovies.map(\.title) == ["Current Year"])
    }

    @Test func rangeLast30FiltersRelativeToToday() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)

        let snapshot = TimelineSnapshotBuilder.build(
            movies: [
                makeMovie(title: "Inside Window", watchedDate: makeDate(year: 2026, month: 3, day: 20, calendar: calendar)),
                makeMovie(title: "Boundary Day", watchedDate: makeDate(year: 2026, month: 3, day: 9, calendar: calendar)),
                makeMovie(title: "Outside Window", watchedDate: makeDate(year: 2026, month: 3, day: 8, calendar: calendar))
            ],
            filterMode: .range,
            selectedRange: .last30,
            selectedYear: 2026,
            today: today,
            calendar: calendar
        )

        #expect(snapshot.filteredMovies.map(\.title) == ["Inside Window", "Boundary Day"])
    }

    @Test func rangeLast90FiltersRelativeToToday() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)

        let snapshot = TimelineSnapshotBuilder.build(
            movies: [
                makeMovie(title: "Inside Window", watchedDate: makeDate(year: 2026, month: 2, day: 1, calendar: calendar)),
                makeMovie(title: "Boundary Day", watchedDate: makeDate(year: 2026, month: 1, day: 8, calendar: calendar)),
                makeMovie(title: "Outside Window", watchedDate: makeDate(year: 2026, month: 1, day: 7, calendar: calendar))
            ],
            filterMode: .range,
            selectedRange: .last90,
            selectedYear: 2026,
            today: today,
            calendar: calendar
        )

        #expect(snapshot.filteredMovies.map(\.title) == ["Inside Window", "Boundary Day"])
    }

    @Test func monthGroupsAreSortedNewestFirstAndKeepMoviesSortedWithinMonth() {
        let calendar = makeCalendar()
        let today = makeDate(year: 2026, month: 4, day: 8, calendar: calendar)

        let snapshot = TimelineSnapshotBuilder.build(
            movies: [
                makeMovie(title: "March Earlier", watchedDate: makeDate(year: 2026, month: 3, day: 2, calendar: calendar)),
                makeMovie(title: "April", watchedDate: makeDate(year: 2026, month: 4, day: 1, calendar: calendar)),
                makeMovie(title: "March Later", watchedDate: makeDate(year: 2026, month: 3, day: 28, calendar: calendar))
            ],
            filterMode: .range,
            selectedRange: .all,
            selectedYear: 2026,
            today: today,
            calendar: calendar
        )

        #expect(snapshot.monthGroups.count == 2)
        #expect(snapshot.monthGroups.map { calendar.component(.month, from: $0.monthStart) } == [4, 3])
        #expect(snapshot.monthGroups[1].movies.map(\.title) == ["March Later", "March Earlier"])
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
