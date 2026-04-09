import Foundation
import Testing
@testable import filmfreaks

struct StatsSnapshotBuilderTests {

    @Test func computeSnapshotRespectsLocationFilter() {
        let movies = [
            makeMovie(title: "Arrival", watchedDate: makeDate(year: 2026, month: 4, day: 1), watchedLocation: "Kino"),
            makeMovie(title: "Alien", watchedDate: makeDate(year: 2026, month: 4, day: 2), watchedLocation: "Wohnzimmer")
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [],
            ratingDisplayMode: .ratingAverage,
            selectedRange: .all,
            selectedLocationFilter: "Kino"
        )

        #expect(snapshot.filteredMovies.map(\.title) == ["Arrival"])
        #expect(snapshot.availableLocations == ["Kino", "Wohnzimmer"])
    }

    @Test func computeSnapshotRespectsTimeRange() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let movies = [
            makeMovie(title: "Recent", watchedDate: makeDate(year: currentYear, month: 3, day: 25), watchedLocation: nil),
            makeMovie(title: "Older", watchedDate: makeDate(year: currentYear - 1, month: 12, day: 15), watchedLocation: nil)
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [],
            ratingDisplayMode: .ratingAverage,
            selectedRange: .thisYear,
            selectedLocationFilter: nil
        )

        #expect(snapshot.moviesForCurrentTimeRange.map(\.title) == ["Recent"])
        #expect(snapshot.filteredMovies.map(\.title) == ["Recent"])
    }

    private func makeMovie(title: String, watchedDate: Date?, watchedLocation: String?) -> Movie {
        Movie(
            title: title,
            year: watchedDate == nil ? "2026" : String(Calendar(identifier: .gregorian).component(.year, from: watchedDate!)),
            watchedDate: watchedDate,
            watchedLocation: watchedLocation
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
}
