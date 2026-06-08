import Testing
@testable import filmfreaks

struct MovieCollectionPresentationTests {

    @Test func collectionPartsAreSortedByReleaseDate() throws {
        let details = MovieMetadataTestFixtures.makeCollectionDetails(
            parts: [
                TMDbCollectionPart(id: 3, title: "Dritter", release_date: "2018-01-01", poster_path: nil, backdrop_path: nil, vote_average: 6.0),
                TMDbCollectionPart(id: 1, title: "Erster", release_date: "2014-01-01", poster_path: nil, backdrop_path: nil, vote_average: 7.0),
                TMDbCollectionPart(id: 2, title: "Zweiter", release_date: "2016-01-01", poster_path: nil, backdrop_path: nil, vote_average: 8.0)
            ]
        )

        let presentation = try #require(
            MovieCollectionPresentation.make(
                collectionDetails: details,
                currentTMDbId: 2,
                watchedMovies: [],
                backlogMovies: []
            )
        )

        #expect(presentation.items.map(\.id) == [1, 2, 3])
        #expect(presentation.items[1].membershipState == .current)
    }

    @Test func membershipBadgesPreferTMDbIDAndFallbackToTitleYear() throws {
        let watched = Movie(title: "Legacy Match", year: "2014", tmdbId: nil)
        let backlog = Movie(title: "Backlog Match", year: "2018", tmdbId: 43)
        let details = MovieMetadataTestFixtures.makeCollectionDetails(
            parts: [
                TMDbCollectionPart(id: 41, title: "Legacy Match", release_date: "2014-01-01", poster_path: nil, backdrop_path: nil, vote_average: 7.0),
                TMDbCollectionPart(id: 42, title: "Current", release_date: "2016-01-01", poster_path: nil, backdrop_path: nil, vote_average: 8.0),
                TMDbCollectionPart(id: 43, title: "Different Title", release_date: "2018-01-01", poster_path: nil, backdrop_path: nil, vote_average: 6.0)
            ]
        )

        let presentation = try #require(
            MovieCollectionPresentation.make(
                collectionDetails: details,
                currentTMDbId: 42,
                watchedMovies: [watched],
                backlogMovies: [backlog]
            )
        )

        let statesByID = Dictionary(uniqueKeysWithValues: presentation.items.map { ($0.id, $0.membershipState) })

        #expect(statesByID[41] == .watched)
        #expect(statesByID[42] == .current)
        #expect(statesByID[43] == .backlog)
    }

    @Test func singlePartCollectionDoesNotCreateLargeSection() {
        let details = MovieMetadataTestFixtures.makeCollectionDetails(
            parts: [
                TMDbCollectionPart(id: 42, title: "Arrival", release_date: "2016-01-01", poster_path: nil, backdrop_path: nil, vote_average: 8.0)
            ]
        )

        let presentation = MovieCollectionPresentation.make(
            collectionDetails: details,
            currentTMDbId: 42,
            watchedMovies: [],
            backlogMovies: []
        )

        #expect(presentation == nil)
    }
}
