import Foundation
import Testing
@testable import filmfreaks

struct MovieRatingEligibilityTests {

    @Test func backlogMovieIsLockedUntilItHasBeenWatched() {
        let backlogMovie = Movie(title: "Arrival", year: "2016")

        let eligibility = MovieRatingEligibility.evaluate(
            movieID: backlogMovie.id,
            watchedMovies: [],
            backlogMovies: [backlogMovie]
        )

        #expect(eligibility == .lockedUntilWatched)
        #expect(eligibility.canSubmitRating == false)
    }

    @Test func watchedMovieIsEligibleEvenDuringATransientListMove() {
        let movie = Movie(title: "Heat", year: "1995")

        let eligibility = MovieRatingEligibility.evaluate(
            movieID: movie.id,
            watchedMovies: [movie],
            backlogMovies: [movie]
        )

        #expect(eligibility == .eligible)
        #expect(eligibility.canSubmitRating)
    }

    @Test func ratingPresentationPlacesTheCurrentMemberBeforeAlphabeticalOrder() {
        let marcID = UUID()
        let ratings = [
            Rating(reviewerName: "Michi", scores: [.action: 2]),
            Rating(reviewerName: "Anna", scores: [.emotion: 3]),
            Rating(reviewerId: marcID, reviewerName: "Marc", scores: [.suspense: 3]),
        ]

        let ordered = MovieRatingPresentation.orderedRatings(
            ratings,
            selectedUserID: marcID,
            selectedUserName: "Marc"
        )

        #expect(ordered.map(\.reviewerName) == ["Marc", "Anna", "Michi"])
    }

    @Test func criterionSummaryIgnoresUnratedValuesInsteadOfCountingThemAsZero() {
        let summary = MovieRatingGroupSummary(
            ratings: [
                Rating(reviewerName: "Marc", scores: [.action: 3, .emotion: 0]),
                Rating(reviewerName: "Michi", scores: [.action: 0, .emotion: 2]),
            ]
        )

        #expect(summary.criterionAverages[.action] == 3.0)
        #expect(summary.criterionRatingsCounts[.action] == 1)
        #expect(summary.criterionAverages[.emotion] == 2.0)
        #expect(summary.criterionRatingsCounts[.emotion] == 1)
    }
}

@MainActor
struct MovieRatingStoreEligibilityTests {

    @Test func storeRejectsRatingWritesForBacklogMovies() async {
        let store = MovieStore(useCloud: false)
        let backlogMovie = Movie(title: "Arrival", year: "2016")

        store.movies = []
        store.backlogMovies = [backlogMovie]

        let didSave = await store.upsertRating(
            for: backlogMovie.id,
            rating: Rating(reviewerName: "Marc", scores: [.action: 3], fazitScore: 9)
        )

        #expect(didSave == false)
        #expect(store.backlogMovies.first?.ratings.isEmpty == true)
    }
}
