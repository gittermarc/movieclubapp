import Foundation
import Testing
@testable import filmfreaks

struct ContentMovieRatingFallbackTests {
    @Test func TMDbSettingControlsSortingOfTextOnlyContributions() {
        let text = Movie(title: "Text", year: "2026", tmdbRating: 9.5, ratings: [
            Rating(reviewerName: "Text", scores: [:], comment: "Nur Text")
        ])
        let numeric = Movie(title: "Kriterien", year: "2026", ratings: [
            Rating(reviewerName: "Kriterien", scores: [.action: 2])
        ])

        for mode in RatingDisplayMode.allCases {
            #expect(sortedTitles([text, numeric], mode: mode, showTMDb: true) == ["Text", "Kriterien"])
            #expect(sortedTitles([text, numeric], mode: mode, showTMDb: false) == ["Kriterien", "Text"])
        }
    }

    @Test func pureTextContributionStillMatchesMemberFilter() {
        let member = User(name: "Marc")
        let text = Movie(title: "Text", year: "2026", ratings: [
            Rating(reviewerId: member.id, reviewerName: member.name, scores: [:], comment: "Nur Text")
        ])
        let snapshot = build([text], mode: .ratingAverage, showTMDb: false, member: member)

        #expect(snapshot.watchedItems.map(\.movieId) == [text.id])
        #expect(snapshot.watchedItems.first?.movie.averageRating == nil)
    }

    private func sortedTitles(_ movies: [Movie], mode: RatingDisplayMode, showTMDb: Bool) -> [String] {
        build(movies, mode: mode, showTMDb: showTMDb).watchedItems.map(\.movie.title)
    }

    private func build(_ movies: [Movie], mode: RatingDisplayMode, showTMDb: Bool, member: User? = nil) -> ContentMovieItemsSnapshot {
        ContentMovieItemsSnapshotBuilder.build(
            input: .init(
                watchedMovies: movies,
                backlogMovies: [],
                watchedSearchText: "",
                backlogSearchText: "",
                filterByUser: member,
                sort: .ratingHigh,
                ratingDisplayMode: mode,
                showTMDbRatingsInLists: showTMDb
            ),
            searchIndex: MovieSearchIndexCache()
        )
    }
}
