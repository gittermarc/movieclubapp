import Foundation
import Testing
@testable import filmfreaks

struct MovieRatingReviewPresentationTests {

    @Test func normalizedCommentTrimsOuterWhitespaceAndPreservesParagraphs() {
        let rawComment = " \r\nErster Absatz.\r\n\r\nZweiter Absatz.\r "

        let comment = MovieRatingReviewPresentation.normalizedComment(rawComment)

        #expect(comment == "Erster Absatz.\n\nZweiter Absatz.")
    }

    @Test func normalizedCommentRejectsMissingOrWhitespaceOnlyText() {
        #expect(MovieRatingReviewPresentation.normalizedComment(nil) == nil)
        #expect(MovieRatingReviewPresentation.normalizedComment(" \n\t ") == nil)
    }

    @Test func evenAShortCommentCanOpenTheFullReview() {
        let rating = Rating(
            reviewerName: "Marc",
            scores: [.humor: 3],
            comment: "Top."
        )

        #expect(MovieRatingReviewPresentation.comment(for: rating) == "Top.")
    }

    @Test func reviewRouteResolvesByStableRatingIDAfterRatingsAreReordered() {
        let targetID = UUID()
        var target = Rating(
            reviewerName: "Marc",
            scores: [.suspense: 3],
            comment: "Die richtige Rezension."
        )
        target.id = targetID

        let other = Rating(
            reviewerName: "Anna",
            scores: [.emotion: 2],
            comment: "Eine andere Rezension."
        )
        let route = MovieRatingReviewRoute(rating: target)

        let resolved = MovieRatingReviewPresentation.rating(
            for: route,
            in: [other, target]
        )

        #expect(resolved?.id == targetID)
        #expect(resolved?.reviewerName == "Marc")
    }
}
