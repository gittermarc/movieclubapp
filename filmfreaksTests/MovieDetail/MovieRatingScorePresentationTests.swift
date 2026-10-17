import Testing
@testable import filmfreaks

struct MovieRatingScorePresentationTests {

    @Test func missingCriteriaUseTheSameEmptyTextInCardsAndReviews() {
        let textRating = Rating(reviewerName: "Marc", scores: [:], comment: "Nur mein Eindruck.")
        let fazitRating = Rating(reviewerName: "Anna", scores: [:], fazitScore: 9)
        let unrated = Rating(reviewerName: "Michi", scores: [.action: 0])

        #expect(MovieRatingPresentation.scoreText(textRating.averageScoreNormalizedTo10) == "Nicht vergeben")
        #expect(MovieRatingPresentation.scoreText(fazitRating.averageScoreNormalizedTo10) == "Nicht vergeben")
        #expect(MovieRatingPresentation.scoreText(unrated.averageScoreNormalizedTo10) == "Nicht vergeben")
        #expect(MovieRatingReviewPresentation.comment(for: textRating) == "Nur mein Eindruck.")
    }

    @Test func presentCriteriaStillDisplayTheirNumericValue() {
        let rating = Rating(reviewerName: "Marc", scores: [.action: 3])

        #expect(MovieRatingPresentation.scoreText(rating.averageScoreNormalizedTo10) == "10.0 / 10")
    }

    @Test func teaserDistinguishesMissingCriteriaFromMissingContributions() {
        #expect(MovieRatingPresentation.missingCriteriaText(ratingsCount: 0) == "Noch keine Bewertungen")
        #expect(MovieRatingPresentation.missingCriteriaText(ratingsCount: 1) == "Kriterien nicht vergeben")
        #expect(MovieRatingPresentation.missingCriteriaText(ratingsCount: 3) == "Kriterien nicht vergeben")
    }

    @Test func textReviewRemainsInTheOrderedContributions() {
        let textRating = Rating(reviewerName: "Anna", scores: [:], comment: "Eine vollständige Rezension.")
        let criteriaRating = Rating(reviewerName: "Marc", scores: [.action: 3])

        let ordered = MovieRatingPresentation.orderedRatings(
            [criteriaRating, textRating],
            selectedUserID: nil,
            selectedUserName: nil
        )

        #expect(ordered.map(\.id) == [textRating.id, criteriaRating.id])
        #expect(MovieRatingReviewPresentation.comment(for: ordered[0]) == "Eine vollständige Rezension.")
    }
}
