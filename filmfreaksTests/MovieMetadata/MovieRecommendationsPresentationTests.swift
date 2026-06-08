import Testing
@testable import filmfreaks

struct MovieRecommendationsPresentationTests {

    @Test func recommendationsFilterCurrentDuplicatesWatchedAndBacklog() throws {
        let watchedMovie = Movie(title: "Watched", year: "2018", tmdbId: 80)
        let backlogMovie = Movie(title: "Backlog", year: "2019", tmdbId: 81)
        let recommendations = [
            MovieMetadataTestFixtures.makeMovieResult(id: 42, title: "Current", releaseDate: "2016-01-01"),
            MovieMetadataTestFixtures.makeMovieResult(id: 70, title: "Fresh", releaseDate: "2017-01-01"),
            MovieMetadataTestFixtures.makeMovieResult(id: 70, title: "Fresh Duplicate", releaseDate: "2017-02-01"),
            MovieMetadataTestFixtures.makeMovieResult(id: 80, title: "Watched", releaseDate: "2018-01-01"),
            MovieMetadataTestFixtures.makeMovieResult(id: 81, title: "Backlog", releaseDate: "2019-01-01"),
            MovieMetadataTestFixtures.makeMovieResult(id: 82, title: "Another Fresh", releaseDate: "2020-01-01")
        ]

        let presentation = try #require(
            MovieRecommendationsPresentation.make(
                recommendations: recommendations,
                source: .recommendations,
                currentTMDbId: 42,
                watchedMovies: [watchedMovie],
                backlogMovies: [backlogMovie]
            )
        )

        #expect(presentation.items.map(\.id) == [70, 82])
        #expect(presentation.subtitle == nil)
    }

    @Test func similarSourceGetsSmallSubtitle() throws {
        let presentation = try #require(
            MovieRecommendationsPresentation.make(
                recommendations: [
                    MovieMetadataTestFixtures.makeMovieResult(id: 70, title: "Fresh")
                ],
                source: .similar,
                currentTMDbId: 42,
                watchedMovies: [],
                backlogMovies: []
            )
        )

        #expect(presentation.title == "Mehr wie dieser Film")
        #expect(presentation.subtitle == "Ähnliche Filme")
    }

    @Test func allKnownRecommendationsReturnNil() {
        let watchedMovie = Movie(title: "Watched", year: "2018", tmdbId: 80)
        let presentation = MovieRecommendationsPresentation.make(
            recommendations: [
                MovieMetadataTestFixtures.makeMovieResult(id: 80, title: "Watched", releaseDate: "2018-01-01")
            ],
            source: .recommendations,
            currentTMDbId: 42,
            watchedMovies: [watchedMovie],
            backlogMovies: []
        )

        #expect(presentation == nil)
    }
}
