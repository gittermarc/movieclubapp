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

    @Test func computeSnapshotBuildsPickInsights() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000052")!, name: "Bob")
        let clara = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000053")!, name: "Clara")
        let dan = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000054")!, name: "Dan")
        let eva = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000055")!, name: "Eva")

        let movies = [
            makeMovie(title: "Safe Harbor", watchedDate: makeDate(year: 2026, month: 6, day: 1), ratings: [
                makeRating(user: alice, fazit: 9),
                makeRating(user: bob, fazit: 9),
                makeRating(user: clara, fazit: 9),
                makeRating(user: dan, fazit: 8)
            ]),
            makeMovie(title: "Crowd Favorite", watchedDate: makeDate(year: 2026, month: 6, day: 2), ratings: [
                makeRating(user: alice, fazit: 8),
                makeRating(user: bob, fazit: 8),
                makeRating(user: clara, fazit: 8),
                makeRating(user: dan, fazit: 8),
                makeRating(user: eva, fazit: 8)
            ]),
            makeMovie(title: "Split Decision", watchedDate: makeDate(year: 2026, month: 6, day: 3), ratings: [
                makeRating(user: alice, fazit: 10),
                makeRating(user: bob, fazit: 10),
                makeRating(user: clara, fazit: 2),
                makeRating(user: dan, fazit: 2),
                makeRating(user: eva, fazit: 8)
            ]),
            makeMovie(title: "Cold Shower", watchedDate: makeDate(year: 2026, month: 6, day: 4), ratings: [
                makeRating(user: alice, fazit: 10),
                makeRating(user: bob, fazit: 1),
                makeRating(user: clara, fazit: 1),
                makeRating(user: dan, fazit: 1),
                makeRating(user: eva, fazit: 10)
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob, clara, dan, eva],
            ratingDisplayMode: .fazitAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.safePick?.movie.title == "Safe Harbor")
        #expect(snapshot.safePick?.ratingsCount == 4)
        #expect(abs((snapshot.safePick?.averageRating ?? 0.0) - 8.75) < 0.0001)

        #expect(snapshot.daringPick?.movie.title == "Split Decision")
        #expect(snapshot.daringPick?.ratingsCount == 5)
        #expect(abs((snapshot.daringPick?.averageRating ?? 0.0) - 6.4) < 0.0001)
        #expect(abs((snapshot.daringPick?.standardDeviation ?? 0.0) - 3.6660605559) < 0.0001)

        #expect(snapshot.crowdPleaser?.movie.title == "Crowd Favorite")
        #expect(snapshot.crowdPleaser?.ratingsCount == 5)
        #expect(abs((snapshot.crowdPleaser?.averageRating ?? 0.0) - 8.0) < 0.0001)
        #expect(abs((snapshot.crowdPleaser?.standardDeviation ?? 0.0) - 0.0) < 0.0001)
    }


    @Test func computeSnapshotBuildsRatingDimensionInsights() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000031")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000032")!, name: "Bob")
        let clara = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000033")!, name: "Clara")

        let movies = [
            makeMovie(title: "One", watchedDate: makeDate(year: 2026, month: 4, day: 1), ratings: [
                makeRating(user: alice, scores: [.music: 3, .ambition: 1, .humor: 3]),
                makeRating(user: bob, scores: [.music: 2, .ambition: 1, .humor: 1]),
                makeRating(user: clara, scores: [.music: 2, .ambition: 2, .humor: 3])
            ]),
            makeMovie(title: "Two", watchedDate: makeDate(year: 2026, month: 4, day: 2), ratings: [
                makeRating(user: alice, scores: [.music: 3, .ambition: 1, .humor: 1]),
                makeRating(user: bob, scores: [.music: 2, .ambition: 1, .humor: 3]),
                makeRating(user: clara, scores: [.music: 1, .ambition: 1, .humor: 1])
            ]),
            makeMovie(title: "Three", watchedDate: makeDate(year: 2026, month: 4, day: 3), ratings: [
                makeRating(user: alice, scores: [.music: 3, .ambition: 1, .humor: 3]),
                makeRating(user: bob, scores: [.music: 2, .ambition: 1, .humor: 1]),
                makeRating(user: clara, scores: [.music: 2, .ambition: 1, .humor: 3])
            ]),
            makeMovie(title: "Four", watchedDate: makeDate(year: 2026, month: 4, day: 4), ratings: [
                makeRating(user: alice, scores: [.music: 3, .ambition: 1, .humor: 1]),
                makeRating(user: bob, scores: [.music: 2, .ambition: 1, .humor: 3]),
                makeRating(user: clara, scores: [.music: 1, .ambition: 1, .humor: 1])
            ]),
            makeMovie(title: "Five", watchedDate: makeDate(year: 2026, month: 4, day: 5), ratings: [
                makeRating(user: alice, scores: [.music: 3, .ambition: 1, .humor: 3]),
                makeRating(user: bob, scores: [.music: 2, .ambition: 1, .humor: 1]),
                makeRating(user: clara, scores: [.music: 2, .ambition: 2, .humor: 3])
            ]),
            makeMovie(title: "Six", watchedDate: makeDate(year: 2026, month: 4, day: 6), ratings: [
                makeRating(user: alice, scores: [.music: 3, .ambition: 1, .humor: 1]),
                makeRating(user: bob, scores: [.music: 2, .ambition: 1, .humor: 3]),
                makeRating(user: clara, scores: [.music: 1, .ambition: 1, .humor: 1])
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob, clara],
            ratingDisplayMode: .ratingAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.strongestCriterion?.criterion == .music)
        #expect(snapshot.strongestCriterion?.ratingsCount == 18)
        #expect(abs((snapshot.strongestCriterion?.averageScore ?? 0.0) - (39.0 / 18.0)) < 0.0001)

        #expect(snapshot.weakestCriterion?.criterion == .ambition)
        #expect(snapshot.weakestCriterion?.ratingsCount == 18)
        #expect(abs((snapshot.weakestCriterion?.averageScore ?? 0.0) - (20.0 / 18.0)) < 0.0001)

        #expect(snapshot.mostControversialCriterion?.criterion == .humor)
        #expect(snapshot.mostControversialCriterion?.ratingsCount == 18)
        #expect(abs((snapshot.mostControversialCriterion?.standardDeviation ?? 0.0) - 1.0) < 0.0001)
        #expect(snapshot.mostControversialCriterion?.isMeaningfullyControversial == true)

        #expect(snapshot.criterionReviewerHighlight?.reviewerName == "Alice")
        #expect(snapshot.criterionReviewerHighlight?.criterion == .music)
        #expect(snapshot.criterionReviewerHighlight?.ratingsCount == 6)
        #expect(abs((snapshot.criterionReviewerHighlight?.reviewerAverageScore ?? 0.0) - 3.0) < 0.0001)
        #expect(abs((snapshot.criterionReviewerHighlight?.groupAverageScore ?? 0.0) - (39.0 / 18.0)) < 0.0001)
        #expect(abs((snapshot.criterionReviewerHighlight?.averageDelta ?? 0.0) - (15.0 / 18.0)) < 0.0001)
    }

    @Test func computeSnapshotSuppressesRatingDimensionInsightsForThinData() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000041")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!, name: "Bob")

        let movies = [
            makeMovie(title: "One", watchedDate: makeDate(year: 2026, month: 5, day: 1), ratings: [
                makeRating(user: alice, scores: [.music: 3]),
                makeRating(user: bob, scores: [.music: 2])
            ]),
            makeMovie(title: "Two", watchedDate: makeDate(year: 2026, month: 5, day: 2), ratings: [
                makeRating(user: alice, scores: [.music: 3]),
                makeRating(user: bob, scores: [.music: 2])
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob],
            ratingDisplayMode: .ratingAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.strongestCriterion == nil)
        #expect(snapshot.weakestCriterion == nil)
        #expect(snapshot.mostControversialCriterion == nil)
        #expect(snapshot.criterionReviewerHighlight == nil)
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

    @Test func computeSnapshotSuppressesPickInsightsForThinData() {
        let alice = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!, name: "Alice")
        let bob = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000062")!, name: "Bob")
        let clara = User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000063")!, name: "Clara")

        let movies = [
            makeMovie(title: "Almost There", watchedDate: makeDate(year: 2026, month: 7, day: 1), ratings: [
                makeRating(user: alice, fazit: 8),
                makeRating(user: bob, fazit: 8),
                makeRating(user: clara, fazit: 8)
            ]),
            makeMovie(title: "Too Wild", watchedDate: makeDate(year: 2026, month: 7, day: 2), ratings: [
                makeRating(user: alice, fazit: 10),
                makeRating(user: bob, fazit: 1),
                makeRating(user: clara, fazit: 10)
            ])
        ]

        let snapshot = StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: [alice, bob, clara],
            ratingDisplayMode: .fazitAverage,
            selectedRange: .all,
            selectedLocationFilter: nil
        )

        #expect(snapshot.safePick == nil)
        #expect(snapshot.daringPick == nil)
        #expect(snapshot.crowdPleaser == nil)
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

    private func makeRating(
        user: User,
        fazit: Int? = nil,
        scores: [RatingCriterion: Int] = [:]
    ) -> Rating {
        Rating(
            reviewerId: user.id,
            reviewerName: user.name,
            scores: scores,
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
