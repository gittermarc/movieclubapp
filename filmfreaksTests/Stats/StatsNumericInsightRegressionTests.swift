import Foundation
import Testing
@testable import filmfreaks

struct StatsNumericInsightRegressionTests {
    private typealias Fixture = StatsRatingRegressionFixtures

    @Test(arguments: RatingDisplayMode.allCases)
    func textContributionsDoNotSatisfyPickOrSuggestionMinimumSampleSizes(mode: RatingDisplayMode) {
        let movies = (1...3).map { index in
            Fixture.movie(title: "Suggestion \(index)", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3]),
                Fixture.rating(user: 1, scores: [.music: 3]),
                Fixture.rating(user: 2, comment: "Nur Text"),
                Fixture.rating(user: 3, scores: [.music: 0]),
                Fixture.rating(user: 4, comment: "Noch ein Text")
            ], suggestedBy: "Alice")
        }
        let snapshot = Fixture.snapshot(movies, mode: mode)

        #expect(snapshot.totalRatingsCount == 15)
        #expect(snapshot.numericRatingsCount == 6)
        #expect(snapshot.safePick == nil)
        #expect(snapshot.daringPick == nil)
        #expect(snapshot.crowdPleaser == nil)
        #expect(snapshot.bestAverageRatingSuggester == nil)
        #expect(snapshot.bestHitRateSuggester == nil)
        #expect(snapshot.mostControversialSuggester == nil)
        #expect(snapshot.fastestToWatchSuggester == nil)
    }

    @Test func suggestionQualityKeepsEqualMovieWeightDespiteDifferentNumbersOfReviewers() {
        let movies = [
            Fixture.movie(title: "High", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3]),
                Fixture.rating(user: 1, scores: [.music: 3]),
                Fixture.rating(user: 2, scores: [.music: 3])
            ], suggestedBy: "Alice"),
            Fixture.movie(title: "Medium", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3]),
                Fixture.rating(user: 1, scores: [.music: 2]),
                Fixture.rating(user: 2, scores: [.music: 1])
            ], suggestedBy: "Alice"),
            Fixture.movie(title: "Low", ratings: (0...4).map { index in
                Fixture.rating(user: index, scores: [.music: 1])
            }, suggestedBy: "Alice")
        ]
        let snapshot = Fixture.snapshot(movies)

        #expect(snapshot.bestAverageRatingSuggester?.ratedSuggestionsCount == 3)
        #expect(Fixture.equals(snapshot.bestAverageRatingSuggester?.averageGroupRating, 20.0 / 3.0))
        #expect(Fixture.equals(snapshot.overallAverageRating, 200.0 / 33.0))
    }

    @Test func suggestionQualityKeepsMovieFazitWhilePicksKeepIndividualFazitFallbacks() {
        let movies = (1...3).map { index in
            Fixture.movie(title: "Fazit suggestion \(index)", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3], fazit: 8),
                Fixture.rating(user: 1, scores: [.music: 1]),
                Fixture.rating(user: 2, scores: [.music: 1]),
                Fixture.rating(user: 3, scores: [.music: 1]),
                Fixture.rating(user: 4, comment: "Nur Text")
            ], suggestedBy: "Alice")
        }
        let snapshot = Fixture.snapshot(movies, mode: .fazitAverage)

        #expect(Fixture.equals(snapshot.bestAverageRatingSuggester?.averageGroupRating, 8))
        #expect(Fixture.equals(snapshot.overallAverageRating, 4.5))
        // Per-person fallback yields 4.5, below the safe/daring-pick average thresholds.
        #expect(snapshot.safePick == nil)
        #expect(snapshot.daringPick == nil)
        #expect(snapshot.crowdPleaser == nil)
    }

    @Test func criterionAndTasteInsightsIgnoreTextAndUnassignedCriterionValues() {
        let movies = (1...3).map { index in
            Fixture.movie(title: "Criterion \(index)", ratings: [
                Fixture.rating(user: 0, scores: [.music: 3, .humor: 1]),
                Fixture.rating(user: 1, scores: [.music: 3, .humor: 1]),
                Fixture.rating(user: 2, scores: [.music: 0, .humor: 0], comment: "Nur Text")
            ])
        }
        let snapshot = Fixture.snapshot(movies)

        #expect(snapshot.strongestCriterion?.criterion == .music)
        #expect(snapshot.strongestCriterion?.ratingsCount == 6)
        #expect(Fixture.equals(snapshot.strongestCriterion?.averageScore, 3))
        #expect(snapshot.weakestCriterion?.criterion == .humor)
        #expect(snapshot.weakestCriterion?.ratingsCount == 6)
        #expect(Fixture.equals(snapshot.weakestCriterion?.averageScore, 1))
        #expect(snapshot.tasteTwins?.firstReviewerName == "Alice")
        #expect(snapshot.tasteTwins?.secondReviewerName == "Bob")
        #expect(snapshot.tasteTwins?.sharedMoviesCount == 3)
        #expect(Fixture.equals(snapshot.tasteTwins?.averageDifference, 0))
        #expect(snapshot.frictionPair == nil)
    }

    @Test func latestTextContributionRemovesOlderNumericEvidenceFromTasteComparisons() {
        let movies = (1...3).map { index in
            var older = Fixture.rating(user: 0, scores: [.music: 3])
            older.updatedAt = Date(timeIntervalSince1970: 100)
            var newer = Fixture.rating(user: 0, comment: "Jetzt ohne Zahlenwertung")
            newer.updatedAt = Date(timeIntervalSince1970: 200)
            return Fixture.movie(title: "Legacy duplicates \(index)", ratings: [
                newer,
                Fixture.rating(user: 1, scores: [.music: 3]),
                older
            ])
        }
        let snapshot = Fixture.snapshot(movies)

        #expect(snapshot.tasteTwins == nil)
        #expect(snapshot.frictionPair == nil)
        #expect(snapshot.strictestReviewer == nil)
        #expect(snapshot.mostGenerousReviewer == nil)
        #expect(snapshot.hotTakeReviewer == nil)
    }
}
