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

    @Test func computeSnapshotBuildsTasteTwinsAndFrictionPair() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Bob")
        let clara = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Clara")

        let movies = [
            makeMovie(title: "One", watchedDate: makeDate(year: 2026, month: 1, day: 1), ratings: [
                makeRating(user: alice, fazit: 7),
                makeRating(user: bob, fazit: 7),
                makeRating(user: clara, fazit: 3)
            ]),
            makeMovie(title: "Two", watchedDate: makeDate(year: 2026, month: 1, day: 2), ratings: [
                makeRating(user: alice, fazit: 8),
                makeRating(user: bob, fazit: 8),
                makeRating(user: clara, fazit: 4)
            ]),
            makeMovie(title: "Three", watchedDate: makeDate(year: 2026, month: 1, day: 3), ratings: [
                makeRating(user: alice, fazit: 6),
                makeRating(user: bob, fazit: 7),
                makeRating(user: clara, fazit: 9)
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob, clara],
            ratingDisplayMode: .fazitAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.tasteTwins?.firstReviewerName == "Alice")
        #expect(snapshot.tasteTwins?.secondReviewerName == "Bob")
        #expect(snapshot.tasteTwins?.sharedMoviesCount == 3)
        #expect(abs((snapshot.tasteTwins?.averageDifference ?? 0.0) - (1.0 / 3.0)) < 0.0001)

        #expect(snapshot.frictionPair?.firstReviewerName == "Alice")
        #expect(snapshot.frictionPair?.secondReviewerName == "Clara")
        #expect(snapshot.frictionPair?.sharedMoviesCount == 3)
        #expect(abs((snapshot.frictionPair?.averageDifference ?? 0.0) - (11.0 / 3.0)) < 0.0001)
    }

    @Test func computeSnapshotBuildsStrictGenerousAndHotTakeInsights() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, name: "Bob")
        let sam = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, name: "Sam")
        let tina = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, name: "Tina")

        let movies = [
            makeMovie(title: "One", watchedDate: makeDate(year: 2026, month: 2, day: 1), ratings: [
                makeRating(user: alice, fazit: 7),
                makeRating(user: bob, fazit: 7),
                makeRating(user: sam, fazit: 4),
                makeRating(user: tina, fazit: 9)
            ]),
            makeMovie(title: "Two", watchedDate: makeDate(year: 2026, month: 2, day: 2), ratings: [
                makeRating(user: alice, fazit: 8),
                makeRating(user: bob, fazit: 8),
                makeRating(user: sam, fazit: 5),
                makeRating(user: tina, fazit: 10)
            ]),
            makeMovie(title: "Three", watchedDate: makeDate(year: 2026, month: 2, day: 3), ratings: [
                makeRating(user: alice, fazit: 6),
                makeRating(user: bob, fazit: 6),
                makeRating(user: sam, fazit: 3),
                makeRating(user: tina, fazit: 8)
            ]),
            makeMovie(title: "Four", watchedDate: makeDate(year: 2026, month: 2, day: 4), ratings: [
                makeRating(user: alice, fazit: 7),
                makeRating(user: bob, fazit: 8),
                makeRating(user: sam, fazit: 4),
                makeRating(user: tina, fazit: 10)
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob, sam, tina],
            ratingDisplayMode: .fazitAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.strictestReviewer?.reviewerName == "Sam")
        #expect(snapshot.strictestReviewer?.comparableRatingsCount == 4)
        #expect(snapshot.mostGenerousReviewer?.reviewerName == "Tina")
        #expect(snapshot.mostGenerousReviewer?.comparableRatingsCount == 4)
        #expect(snapshot.hotTakeReviewer?.reviewerName == "Sam")
        #expect(snapshot.hotTakeReviewer?.hotTakeCount == 4)
        #expect(snapshot.hotTakeReviewer?.comparableRatingsCount == 4)
    }

    @Test func computeSnapshotSuppressesTasteInsightsForThinData() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000022")!, name: "Bob")

        let movies = [
            makeMovie(title: "One", watchedDate: makeDate(year: 2026, month: 3, day: 1), ratings: [
                makeRating(user: alice, fazit: 7),
                makeRating(user: bob, fazit: 7)
            ]),
            makeMovie(title: "Two", watchedDate: makeDate(year: 2026, month: 3, day: 2), ratings: [
                makeRating(user: alice, fazit: 8),
                makeRating(user: bob, fazit: 6)
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob],
            ratingDisplayMode: .fazitAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.tasteTwins == nil)
        #expect(snapshot.frictionPair == nil)
        #expect(snapshot.strictestReviewer == nil)
        #expect(snapshot.mostGenerousReviewer == nil)
        #expect(snapshot.hotTakeReviewer == nil)
    }

    private func makeMovie(
        title: String,
        watchedDate: Date?,
        watchedLocation: String? = nil,
        ratings: [Rating] = []
    ) -> Movie {
        Movie(
            title: title,
            year: watchedDate == nil ? "2026" : String(Calendar(identifier: .gregorian).component(.year, from: watchedDate!)),
            ratings: ratings,
            watchedDate: watchedDate,
            watchedLocation: watchedLocation
        )
    }

    private func makeRating(user: User, fazit: Int) -> Rating {
        Rating(
            reviewerId: user.id,
            reviewerName: user.name,
            scores: [:],
            comment: nil,
            fazitScore: fazit,
            updatedAt: nil
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
