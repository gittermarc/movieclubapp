import Foundation
import Testing
@testable import filmfreaks

struct MovieDiscoverySeedBuilderTests {
    @Test func textContributionDoesNotLowerTheCriteriaRankOfASeed() {
        let best = makeMovie(
            id: 20,
            date: 20,
            ratings: [
                Rating(reviewerName: "Criteria", scores: [.action: 3]),
                Rating(reviewerName: "Text", scores: [:], comment: "Nur ein Kommentar")
            ]
        )
        let alternative = makeMovie(id: 21, date: 10, ratings: [Rating(reviewerName: "Fazit", scores: [:], fazitScore: 9)])

        let seeds = MovieDiscoverySeedBuilder.seedMovies(from: recentMovies + [alternative, best], limit: 2)

        #expect(seeds.map(\.tmdbId) == [1, 20])
    }

    @Test func discoveryPreservesEqualReviewerWeightWithDifferentCriteriaCounts() {
        let balanced = makeMovie(
            id: 20,
            date: 20,
            ratings: [
                Rating(reviewerName: "One", scores: [.action: 3]),
                Rating(reviewerName: "Several", scores: [.action: 1, .emotion: 1, .music: 1])
            ]
        )
        let alternative = makeMovie(id: 21, date: 10, ratings: [Rating(reviewerName: "Fazit", scores: [:], fazitScore: 6)])

        let seeds = MovieDiscoverySeedBuilder.seedMovies(from: recentMovies + [alternative, balanced], limit: 2)

        #expect(seeds.map(\.tmdbId) == [1, 20])
    }

    @Test func discoveryKeepsFazitFirstPolicyForMixedRatings() {
        let mixed = makeMovie(id: 20, date: 20, ratings: [Rating(reviewerName: "Mixed", scores: [.action: 3], fazitScore: 4)])
        let fazitOnly = makeMovie(id: 21, date: 10, ratings: [Rating(reviewerName: "Fazit", scores: [:], fazitScore: 8)])

        let seeds = MovieDiscoverySeedBuilder.seedMovies(from: recentMovies + [mixed, fazitOnly], limit: 2)

        #expect(seeds.map(\.tmdbId) == [1, 21])
    }

    @Test func textOnlyMoviesRemainRecentSeedsWithoutUsingTheirTMDbRating() {
        var textOnly = makeMovie(id: 20, date: 20, ratings: [Rating(reviewerName: "Text", scores: [:], comment: "Ein Beitrag")])
        textOnly.tmdbRating = 10
        let numeric = makeMovie(id: 21, date: 10, ratings: [Rating(reviewerName: "Fazit", scores: [:], fazitScore: 5)])

        let ranked = MovieDiscoverySeedBuilder.seedMovies(from: recentMovies + [textOnly, numeric], limit: 2)
        let onlyText = MovieDiscoverySeedBuilder.seedMovies(from: [textOnly])

        #expect(ranked.map(\.tmdbId) == [1, 21])
        #expect(onlyText.map(\.tmdbId) == [20])
    }

    private var recentMovies: [Movie] {
        [makeMovie(id: 1, date: 300), makeMovie(id: 2, date: 200), makeMovie(id: 3, date: 100)]
    }

    private func makeMovie(id: Int, date: TimeInterval, ratings: [Rating] = []) -> Movie {
        Movie(
            title: "Movie \(id)",
            year: "2026",
            ratings: ratings,
            watchedDate: Date(timeIntervalSince1970: date),
            tmdbId: id
        )
    }
}
