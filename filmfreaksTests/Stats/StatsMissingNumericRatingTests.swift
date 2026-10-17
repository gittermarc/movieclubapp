import Testing
@testable import filmfreaks

struct StatsMissingNumericRatingTests {
    private typealias Fixture = StatsRatingRegressionFixtures

    @Test func criteriaStatisticsKeepTextAndFazitAsContributionsWithoutZeroSamples() {
        let movie = Fixture.movie(ratings: [
            Fixture.rating(user: 0, scores: [.music: 3]),
            Fixture.rating(user: 1, comment: "Eine starke Besetzung."),
            Fixture.rating(user: 2, fazit: 8)
        ])
        let snapshot = Fixture.snapshot([movie])

        #expect(snapshot.totalRatingsCount == 3)
        #expect(snapshot.numericRatingsCount == 1)
        #expect(snapshot.activeReviewersCount == 3)
        #expect(snapshot.ratedMoviesCount == 1)
        #expect(Fixture.equals(snapshot.overallAverageRating, 10))
        #expect(Fixture.equals(snapshot.monthTrends.first?.averageRating, 10))
        #expect(Fixture.equals(snapshot.topRatedHighlights.first?.value, 10))
        #expect(snapshot.controversialHighlights.isEmpty)
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.movieCount == 1)
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.ratingsCount == 1)
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.numericRatingsCount == 0)
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.averageRating == nil)
        #expect(snapshot.userStatsByUserId[Fixture.users[2].id]?.ratingsCount == 1)
        #expect(snapshot.userStatsByUserId[Fixture.users[2].id]?.numericRatingsCount == 0)
        #expect(movie.ratings[1].comment == "Eine starke Besetzung.")
        #expect(movie.ratings[2].fazitScore == 8)
    }

    @Test(arguments: RatingDisplayMode.allCases)
    func entirelyMissingNumbersProduceEmptyAveragesAndKeepActivity(mode: RatingDisplayMode) {
        let movie = Fixture.movie(ratings: [
            Fixture.rating(user: 0, comment: "Nur Text"),
            Fixture.rating(user: 1, scores: [.music: 0, .humor: 0]),
            Fixture.rating(user: 2)
        ])
        let snapshot = Fixture.snapshot([movie], mode: mode)

        #expect(snapshot.totalRatingsCount == 3)
        #expect(snapshot.numericRatingsCount == 0)
        #expect(snapshot.activeReviewersCount == 3)
        #expect(snapshot.ratedMoviesCount == 1)
        #expect(snapshot.unratedMoviesCount == 0)
        #expect(snapshot.overallAverageRating == nil)
        #expect(snapshot.monthTrends.count == 1)
        #expect(snapshot.monthTrends.first?.averageRating == nil)
        #expect(snapshot.topRatedHighlights.isEmpty)
        #expect(snapshot.criticGapEntries.isEmpty)
        #expect(snapshot.controversialHighlights.isEmpty)
        #expect(snapshot.safePick == nil)
        #expect(snapshot.daringPick == nil)
        #expect(snapshot.crowdPleaser == nil)
    }

    @Test func overallAndMonthlyMeansPreservePerContributionWeighting() {
        let movies = [
            Fixture.movie(title: "Two numeric reviewers", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3]),
                Fixture.rating(user: 1, scores: [.music: 1, .humor: 1, .ambition: 1]),
                Fixture.rating(user: 2, comment: "Nur Text")
            ]),
            Fixture.movie(title: "One numeric reviewer", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3, .humor: 0]),
                Fixture.rating(user: 1, comment: "Noch ein Text")
            ])
        ]
        let snapshot = Fixture.snapshot(movies)

        // Three person averages, not five individual criterion values or two movie averages.
        #expect(snapshot.numericRatingsCount == 3)
        #expect(snapshot.totalRatingsCount == 5)
        #expect(Fixture.equals(snapshot.overallAverageRating, 70.0 / 9.0))
        #expect(Fixture.equals(snapshot.monthTrends.first?.averageRating, 70.0 / 9.0))
        #expect(Fixture.equals(movies[0].averageRating, 20.0 / 3.0))
        #expect(Fixture.equals(snapshot.userStatsByUserId[Fixture.users[1].id]?.averageRating, 10.0 / 3.0))
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.ratingsCount == 2)
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.numericRatingsCount == 1)
    }

    @Test func fazitTrendsRetainPerPersonFallbackWhileMovieHighlightsUseGroupFazit() {
        let movie = Fixture.movie(ratings: [
            Fixture.rating(user: 0, scores: [.music: 3], fazit: 8),
            Fixture.rating(user: 1, scores: [.music: 1]),
            Fixture.rating(user: 2, comment: "Nur Text")
        ])
        let snapshot = Fixture.snapshot([movie], mode: .fazitAverage)

        #expect(snapshot.totalRatingsCount == 3)
        #expect(snapshot.numericRatingsCount == 2)
        #expect(Fixture.equals(snapshot.overallAverageRating, 17.0 / 3.0))
        #expect(Fixture.equals(snapshot.monthTrends.first?.averageRating, 17.0 / 3.0))
        #expect(Fixture.equals(snapshot.topRatedHighlights.first?.value, 8))
        #expect(snapshot.userStatsByUserId[Fixture.users[1].id]?.numericRatingsCount == 1)
        #expect(Fixture.equals(snapshot.userStatsByUserId[Fixture.users[1].id]?.averageRating, 10.0 / 3.0))
    }

    @Test func fazitOnlyContributionsSupplyNumbersOnlyInFazitMode() {
        let movie = Fixture.movie(ratings: [
            Fixture.rating(user: 0, fazit: 9),
            Fixture.rating(user: 1, comment: "Nur Text")
        ])
        let criteria = Fixture.snapshot([movie])
        let fazit = Fixture.snapshot([movie], mode: .fazitAverage)

        #expect(criteria.totalRatingsCount == 2)
        #expect(criteria.numericRatingsCount == 0)
        #expect(criteria.overallAverageRating == nil)
        #expect(criteria.topRatedHighlights.isEmpty)
        #expect(fazit.totalRatingsCount == 2)
        #expect(fazit.numericRatingsCount == 1)
        #expect(Fixture.equals(fazit.overallAverageRating, 9))
        #expect(Fixture.equals(fazit.topRatedHighlights.first?.value, 9))
    }
}
