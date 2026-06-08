import Foundation
import Testing
@testable import filmfreaks

struct RatingDeleteKeyIndexTests {

    @Test func emptyDeletesProduceEmptyIndex() {
        let index = RatingDeleteKeyIndex(deletedKeys: [])

        #expect(index.isEmpty)
        #expect(index.reviewerKeys(for: UUID()).isEmpty)
    }

    @Test func groupsReviewerKeysByMovieId() {
        let movieA = UUID()
        let movieB = UUID()
        let reviewerA = UUID().uuidString.lowercased()
        let reviewerB = UUID().uuidString.lowercased()
        let reviewerC = UUID().uuidString.lowercased()

        let index = RatingDeleteKeyIndex(deletedKeys: [
            (movieId: movieA, reviewerKey: reviewerA),
            (movieId: movieA, reviewerKey: reviewerB),
            (movieId: movieB, reviewerKey: reviewerC)
        ])

        #expect(index.reviewerKeys(for: movieA) == Set([reviewerA, reviewerB]))
        #expect(index.reviewerKeys(for: movieB) == Set([reviewerC]))
    }

    @Test func normalizesReviewerKeysAndDeduplicatesDuplicates() {
        let movieId = UUID()
        let reviewerKey = UUID().uuidString

        let index = RatingDeleteKeyIndex(deletedKeys: [
            (movieId: movieId, reviewerKey: "  \(reviewerKey.uppercased())  "),
            (movieId: movieId, reviewerKey: reviewerKey.lowercased()),
            (movieId: movieId, reviewerKey: "   ")
        ])

        #expect(index.reviewerKeys(for: movieId) == Set([reviewerKey.lowercased()]))
        #expect(index.contains(movieId: movieId, reviewerKey: reviewerKey.uppercased()))
    }

    @Test func removesOnlyRatingsMatchingMovieAndReviewerKeys() {
        let movieId = UUID()
        let otherMovieId = UUID()
        let deletedReviewerId = UUID()
        let keptReviewerId = UUID()
        let otherMovieReviewerId = UUID()

        let deletedRating = Rating(
            reviewerId: deletedReviewerId,
            reviewerName: "Deleted",
            scores: [.action: 1]
        )
        let keptRating = Rating(
            reviewerId: keptReviewerId,
            reviewerName: "Kept",
            scores: [.action: 2]
        )
        let otherMovieRating = Rating(
            reviewerId: otherMovieReviewerId,
            reviewerName: "Other Movie",
            scores: [.action: 3]
        )

        let index = RatingDeleteKeyIndex(deletedKeys: [
            (movieId: movieId, reviewerKey: deletedReviewerId.uuidString),
            (movieId: otherMovieId, reviewerKey: otherMovieReviewerId.uuidString)
        ])

        let remaining = index.removingDeletedRatings(
            from: [deletedRating, keptRating, otherMovieRating],
            movieId: movieId,
            reviewerKey: { rating in rating.reviewerId?.uuidString.lowercased() ?? rating.reviewerName.lowercased() }
        )

        #expect(remaining == [keptRating, otherMovieRating])
    }

    @Test func deleteKeysForOtherMoviesDoNotRemoveLocalRatings() {
        let movieId = UUID()
        let otherMovieId = UUID()
        let reviewerId = UUID()
        let rating = Rating(
            reviewerId: reviewerId,
            reviewerName: "Reviewer",
            scores: [.action: 2]
        )
        let index = RatingDeleteKeyIndex(deletedKeys: [
            (movieId: otherMovieId, reviewerKey: reviewerId.uuidString)
        ])

        let remaining = index.removingDeletedRatings(
            from: [rating],
            movieId: movieId,
            reviewerKey: { rating in rating.reviewerId?.uuidString.lowercased() ?? rating.reviewerName.lowercased() }
        )

        #expect(remaining == [rating])
    }
}
