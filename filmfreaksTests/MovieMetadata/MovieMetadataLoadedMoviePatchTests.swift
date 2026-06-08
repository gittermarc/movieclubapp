import Testing
@testable import filmfreaks

struct MovieMetadataLoadedMoviePatchTests {

    @Test func mapsPersistableTMDbDetailsIntoMoviePatch() {
        let patch = MovieMetadataLoadedMoviePatch(
            details: MovieMetadataTestFixtures.makeDetails()
        )

        var movie = Movie(title: "Arrival", year: "2016", tmdbId: 42)
        patch.apply(to: &movie)

        #expect(movie.tmdbRating == 8.4)
        #expect(movie.posterPath == "/poster.jpg")
        #expect(movie.genres == ["Science Fiction", "Drama"])
        #expect(movie.genreIds == [1, 2])
        #expect(movie.keywords == ["First Contact", "Arrival"])
        #expect(movie.keywordIds == [10, 11])
        #expect(movie.cast?.map(\.name) == ["Amy Adams", "Jeremy Renner"])
        #expect(movie.directors?.map(\.name) == ["Denis Villeneuve"])
    }

    @Test func skipsEmptyMetadataCollectionsWhenApplyingPatch() {
        let details = MovieMetadataTestFixtures.makeDetails(
            genres: [],
            keywords: TMDbKeywordsResponse(keywords: [], results: nil),
            credits: TMDbCredits(cast: [], crew: [])
        )
        let patch = MovieMetadataLoadedMoviePatch(details: details)

        var movie = Movie(
            title: "Arrival",
            year: "2016",
            tmdbRating: 1.0,
            posterPath: "/old.jpg",
            tmdbId: 42,
            genres: ["Alt"],
            genreIds: [99],
            keywords: ["Legacy"],
            keywordIds: [199],
            cast: [CastMember(personId: 7, name: "Legacy Actor")],
            directors: [CastMember(personId: 8, name: "Legacy Director")]
        )
        patch.apply(to: &movie)

        #expect(movie.genres == ["Alt"])
        #expect(movie.genreIds == [99])
        #expect(movie.keywords == ["Legacy"])
        #expect(movie.keywordIds == [199])
        #expect(movie.cast?.map(\.name) == ["Legacy Actor"])
        #expect(movie.directors?.map(\.name) == ["Legacy Director"])
        #expect(movie.tmdbRating == 8.4)
        #expect(movie.posterPath == "/poster.jpg")
    }
}
