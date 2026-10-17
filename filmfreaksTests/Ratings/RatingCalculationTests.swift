import Foundation
import Testing
@testable import filmfreaks

struct RatingCalculationTests {
    @Test func textOnlyAndUnratedCriteriaHaveNoNumericScore() {
        let ratings = [
            Rating(reviewerName: "Text", scores: [:], comment: "Ein guter Film."),
            Rating(reviewerName: "Leer", scores: [.action: 0, .music: 0]),
            Rating(reviewerName: "Fazit", scores: [.humor: 0], fazitScore: 8)
        ]

        for rating in ratings {
            #expect(rating.averageStars == nil)
            #expect(rating.averageScoreNormalizedTo10 == nil)
        }
        #expect(RatingCalculation.criteriaAverage(ratings: ratings) == nil)
        #expect(RatingCalculation.fazitAverage(ratings: ratings) == 8)
        #expect(RatingCalculation.average([]) == nil)
    }

    @Test func criteriaAverageIgnoresZeroAndMissingCriteria() throws {
        let rating = Rating(reviewerName: "Marc", scores: [.action: 3, .emotion: 0, .music: 2])

        #expect(rating.averageStars == 2.5)
        let score = try #require(rating.averageScoreNormalizedTo10)
        #expect(abs(score - (25.0 / 3.0)) < 0.0001)
    }

    @Test func extraTextAndFazitContributionsDoNotLowerTenOutOfTen() {
        let movie = Movie(title: "Test", year: "2026", ratings: [
            Rating(reviewerName: "Kriterien", scores: [.action: 3]),
            Rating(reviewerName: "Text", scores: [:], comment: "Sehenswert"),
            Rating(reviewerName: "Fazit", scores: [:], fazitScore: 6),
            Rating(reviewerName: "Null", scores: [.music: 0])
        ])

        #expect(movie.ratings.count == 4)
        #expect(movie.averageRating == 10)
        #expect(movie.averageFazit == 6)
        #expect(movie.groupAverage(for: .ratingAverage) == 10)
        #expect(movie.groupAverage(for: .fazitAverage) == 6)
    }

    @Test func eachPersonCountsEquallyDespiteDifferentCriterionCounts() throws {
        let movie = Movie(title: "Test", year: "2026", ratings: [
            Rating(reviewerName: "Ein Kriterium", scores: [.action: 3]),
            Rating(reviewerName: "Drei Kriterien", scores: [.action: 1, .emotion: 1, .music: 1])
        ])

        let average = try #require(movie.averageRating)
        #expect(abs(average - (20.0 / 3.0)) < 0.0001)
        #expect(abs(average - 5.0) > 1)
    }

    @Test func fazitFallbackIsAppliedToTheWholeFilm() throws {
        let criteria = Rating(reviewerName: "Kriterien", scores: [.action: 3])
        let fazit = Rating(reviewerName: "Fazit", scores: [:], fazitScore: 4)
        let mixed = Movie(title: "Gemischt", year: "2026", ratings: [criteria, fazit])
        let legacy = Movie(title: "Ohne Fazit", year: "2026", ratings: [criteria])

        #expect(mixed.groupAverage(for: .fazitAverage) == 4)
        #expect(legacy.groupAverage(for: .fazitAverage) == 10)
        let individualValues = mixed.ratings.compactMap {
            RatingCalculation.value(for: $0, displayMode: .fazitAverage)
        }
        let individualAverage = try #require(RatingCalculation.average(individualValues))
        #expect(individualAverage == 7)
    }

    @Test func completelyMissingNumbersStayAbsentAndAllowTMDbFallback() {
        let movie = Movie(title: "Text", year: "2026", tmdbRating: 8.2, ratings: [
            Rating(reviewerName: "Text", scores: [.action: 0], comment: "Nur ein Kommentar")
        ])

        for mode in RatingDisplayMode.allCases {
            #expect(movie.groupAverage(for: mode) == nil)
            #expect(movie.displayAverage(for: mode) == 8.2)
            #expect(RatingCalculation.value(for: movie.ratings[0], displayMode: mode) == nil)
        }
        #expect(movie.averageFazit == nil)
        #expect(Movie(title: "Leer", year: "2026").displayAverage(for: .fazitAverage) == nil)
    }

    @Test func pureCalculationCanRunInDetachedTask() async {
        let movie = Movie(title: "Detached", year: "2026", ratings: [
            Rating(reviewerName: "Kriterien", scores: [.action: 3]),
            Rating(reviewerName: "Text", scores: [:], comment: "Text")
        ])

        let value = await Task.detached {
            RatingCalculation.criteriaAverage(ratings: movie.ratings)
        }.value
        #expect(value == 10)
    }
}
