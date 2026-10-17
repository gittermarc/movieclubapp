import Testing
@testable import filmfreaks

struct MovieRatingGroupSummaryTests {

    @Test func textAndUnratedContributionsHaveNoNumericGroupValues() {
        let summary = MovieRatingGroupSummary(ratings: [
            Rating(reviewerName: "Marc", scores: [:], comment: "Hat mir gefallen."),
            Rating(reviewerName: "Anna", scores: [.action: 0, .music: 0]),
        ])

        #expect(summary.ratingsCount == 2)
        #expect(summary.criteriaRatingsCount == 0)
        #expect(summary.fazitRatingsCount == 0)
        #expect(summary.averageRating == nil)
        #expect(summary.averageFazit == nil)
        #expect(summary.criterionAverages.isEmpty)
        #expect(summary.criterionRatingsCounts.values.allSatisfy { $0 == 0 })
    }

    @Test func mixedContributionsCountOnlyPresentScoresForEachMetric() {
        let summary = MovieRatingGroupSummary(ratings: [
            Rating(reviewerName: "Marc", scores: [.action: 3]),
            Rating(reviewerName: "Anna", scores: [:], comment: "Eine Rezension."),
            Rating(reviewerName: "Michi", scores: [:], fazitScore: 8),
            Rating(reviewerName: "Claudia", scores: [.emotion: 0]),
        ])

        #expect(summary.ratingsCount == 4)
        #expect(summary.criteriaRatingsCount == 1)
        #expect(summary.averageRating == 10)
        #expect(summary.fazitRatingsCount == 1)
        #expect(summary.averageFazit == 8)
        #expect(summary.criterionAverages[.action] == 3)
        #expect(summary.criterionRatingsCounts[.action] == 1)
        #expect(summary.criterionAverages[.emotion] == nil)
    }

    @Test func eachMemberHasEqualWeightDespiteDifferentNumberOfCriteria() throws {
        let summary = MovieRatingGroupSummary(ratings: [
            Rating(reviewerName: "Marc", scores: [.action: 3]),
            Rating(reviewerName: "Anna", scores: [.action: 1, .music: 1, .emotion: 1]),
        ])

        #expect(summary.criteriaRatingsCount == 2)
        let average = try #require(summary.averageRating)
        let expectedPersonAverage = (10.0 + 10.0 / 3.0) / 2.0
        #expect(abs(average - expectedPersonAverage) < 0.000001)
        #expect(summary.criterionAverages[.action] == 2)
        #expect(summary.criterionRatingsCounts[.action] == 2)
        #expect(summary.criterionRatingsCounts[.music] == 1)
    }

    @Test func emptySummaryHasNoNumericValues() {
        let summary = MovieRatingGroupSummary(ratings: [])

        #expect(summary.ratingsCount == 0)
        #expect(summary.criteriaRatingsCount == 0)
        #expect(summary.fazitRatingsCount == 0)
        #expect(summary.averageRating == nil)
        #expect(summary.averageFazit == nil)
    }
}
