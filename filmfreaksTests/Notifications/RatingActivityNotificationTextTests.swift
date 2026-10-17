import Testing
@testable import filmfreaks

struct RatingActivityNotificationTextTests {
    @Test func textOnlyContributionDoesNotInventANumericRating() {
        let rating = Rating(reviewerName: "Marc", scores: [:], comment: "Sehenswert")

        #expect(RatingActivityNotificationText.body(for: rating) == "Marc hat eine Bewertung abgegeben.")
    }

    @Test func exclusivelyUnratedCriteriaDoNotInventANumericRating() {
        let rating = Rating(reviewerName: "Marc", scores: [.action: 0, .emotion: 0])

        #expect(RatingActivityNotificationText.body(for: rating) == "Marc hat eine Bewertung abgegeben.")
    }

    @Test func fazitOnlyContributionKeepsItsNumericRating() {
        let rating = Rating(reviewerName: "Marc", scores: [:], fazitScore: 8)

        #expect(RatingActivityNotificationText.body(for: rating) == "Marc hat eine Bewertung abgegeben (8/10).")
    }

    @Test func criteriaFallbackKeepsExistingWholeNumberRounding() {
        let rating = Rating(reviewerName: "Marc", scores: [.action: 2, .emotion: 0])

        #expect(RatingActivityNotificationText.body(for: rating) == "Marc hat eine Bewertung abgegeben (7/10).")
    }

    @Test func fazitTakesPrecedenceOverCriteriaInNotificationText() {
        let rating = Rating(reviewerName: "Marc", scores: [.action: 3], fazitScore: 4)

        #expect(RatingActivityNotificationText.body(for: rating) == "Marc hat eine Bewertung abgegeben (4/10).")
    }
}
