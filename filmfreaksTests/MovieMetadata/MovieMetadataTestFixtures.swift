import Foundation
@testable import filmfreaks

nonisolated enum MovieMetadataTestFixtures {
    static func makeDetails(
        id: Int = 42,
        title: String = "Arrival",
        originalTitle: String? = nil,
        originalLanguage: String? = "en",
        releaseDate: String? = "2016-11-10",
        voteAverage: Double = 8.4,
        posterPath: String? = "/poster.jpg",
        backdropPath: String? = "/backdrop.jpg",
        genres: [TMDbGenre]? = [
            TMDbGenre(id: 1, name: "Science Fiction"),
            TMDbGenre(id: 2, name: "Drama")
        ],
        keywords: TMDbKeywordsResponse? = TMDbKeywordsResponse(
            keywords: [
                TMDbKeyword(id: 10, name: "First Contact"),
                TMDbKeyword(id: 11, name: "Arrival")
            ],
            results: nil
        ),
        credits: TMDbCredits? = TMDbCredits(
            cast: [
                TMDbCast(id: 100, name: "Amy Adams", popularity: 12.0, character: "Louise", profile_path: nil),
                TMDbCast(id: 101, name: "Jeremy Renner", popularity: 11.0, character: "Ian", profile_path: nil)
            ],
            crew: [
                TMDbCrew(id: 200, name: "Denis Villeneuve", popularity: 10.0, job: "Director")
            ]
        ),
        images: TMDbMovieImagesResponse? = TMDbMovieImagesResponse(backdrops: [], logos: [], posters: []),
        releaseDates: TMDbReleaseDatesResponse? = TMDbReleaseDatesResponse(results: []),
        productionCompanies: [TMDbProductionCompany]? = [
            TMDbProductionCompany(
                id: 1,
                logo_path: nil,
                name: "FilmNation Entertainment",
                origin_country: "US"
            )
        ],
        productionCountries: [TMDbProductionCountry]? = [
            TMDbProductionCountry(iso_3166_1: "US", name: "United States of America")
        ],
        spokenLanguages: [TMDbSpokenLanguage]? = [
            TMDbSpokenLanguage(english_name: "English", iso_639_1: "en", name: "English")
        ],
        status: String? = "Released",
        homepage: String? = "https://example.com/arrival",
        budget: Int? = 47_000_000,
        revenue: Int? = 203_000_000,
        belongsToCollection: TMDbCollectionSummary? = nil
    ) -> TMDbMovieDetails {
        TMDbMovieDetails(
            id: id,
            title: title,
            tagline: "Why are they here?",
            overview: "Aliens arrive.",
            release_date: releaseDate,
            original_title: originalTitle ?? title,
            original_language: originalLanguage,
            runtime: 116,
            vote_average: voteAverage,
            poster_path: posterPath,
            credits: credits,
            keywords: keywords,
            videos: TMDbVideosResponse(results: []),
            genres: genres,
            backdrop_path: backdropPath,
            belongs_to_collection: belongsToCollection,
            images: images,
            release_dates: releaseDates,
            external_ids: TMDbExternalIDs(
                imdb_id: "tt2543164",
                wikidata_id: nil,
                facebook_id: nil,
                instagram_id: nil,
                twitter_id: nil
            ),
            production_companies: productionCompanies,
            production_countries: productionCountries,
            spoken_languages: spokenLanguages,
            status: status,
            homepage: homepage,
            budget: budget,
            revenue: revenue
        )
    }

    static func makeCollectionSummary(id: Int = 900, name: String = "Arrival Collection") -> TMDbCollectionSummary {
        TMDbCollectionSummary(
            id: id,
            name: name,
            poster_path: "/collection-poster.jpg",
            backdrop_path: "/collection-backdrop.jpg"
        )
    }

    static func makeCollectionDetails(
        id: Int = 900,
        name: String = "Arrival Collection",
        parts: [TMDbCollectionPart] = [
            TMDbCollectionPart(
                id: 41,
                title: "Before Arrival",
                release_date: "2014-01-01",
                poster_path: "/before.jpg",
                backdrop_path: "/before-backdrop.jpg",
                vote_average: 7.0
            ),
            TMDbCollectionPart(
                id: 42,
                title: "Arrival",
                release_date: "2016-11-10",
                poster_path: "/arrival.jpg",
                backdrop_path: "/arrival-backdrop.jpg",
                vote_average: 8.4
            )
        ]
    ) -> TMDbCollectionDetails {
        TMDbCollectionDetails(
            id: id,
            name: name,
            overview: "A compact test collection.",
            poster_path: "/collection-poster.jpg",
            backdrop_path: "/collection-backdrop.jpg",
            parts: parts
        )
    }

    static func makeMovieResult(
        id: Int = 70,
        title: String = "Fresh",
        releaseDate: String? = "2017-01-01",
        voteAverage: Double = 7.3,
        posterPath: String? = "/fresh.jpg",
        backdropPath: String? = "/fresh-backdrop.jpg"
    ) -> TMDbMovieResult {
        TMDbMovieResult(
            id: id,
            title: title,
            release_date: releaseDate,
            vote_average: voteAverage,
            poster_path: posterPath,
            backdrop_path: backdropPath
        )
    }

    static func makeCompleteMovie(
        id: UUID = UUID(),
        title: String = "Arrival",
        year: String = "2016",
        tmdbId: Int = 42
    ) -> Movie {
        Movie(
            id: id,
            title: title,
            year: year,
            tmdbRating: 8.4,
            posterPath: "/poster.jpg",
            tmdbId: tmdbId,
            genres: ["Science Fiction", "Drama"],
            genreIds: [1, 2],
            keywords: ["First Contact", "Arrival"],
            keywordIds: [10, 11],
            cast: [
                CastMember(personId: 100, name: "Amy Adams"),
                CastMember(personId: 101, name: "Jeremy Renner")
            ],
            directors: [
                CastMember(personId: 200, name: "Denis Villeneuve")
            ]
        )
    }

    static func makeSearchResponse(results: [TMDbMovieResult]) -> TMDbSearchResponse {
        TMDbSearchResponse(
            page: 1,
            results: results,
            total_pages: 1,
            total_results: results.count
        )
    }

    static func makeProviders(link: String = "https://example.com/de") -> TMDbWatchProvidersCountry {
        TMDbWatchProvidersCountry(
            link: link,
            flatrate: [
                TMDbWatchProvider(
                    provider_id: 1,
                    provider_name: "StreamNow",
                    logo_path: nil,
                    display_priority: 1
                )
            ],
            ads: nil,
            free: nil,
            rent: nil,
            buy: nil
        )
    }
}

actor MovieMetadataRepositoryProbe {
    private var detailCallCount = 0
    private var providerCallCount = 0
    private var providerRegions: [String?] = []
    private var collectionIDs: [Int] = []
    private var recommendationCallCount = 0
    private var similarCallCount = 0

    func recordDetails() {
        detailCallCount += 1
    }

    func recordProvider(region: String?) {
        providerCallCount += 1
        providerRegions.append(region)
    }

    func recordCollection(id: Int) {
        collectionIDs.append(id)
    }

    func recordRecommendations() {
        recommendationCallCount += 1
    }

    func recordSimilar() {
        similarCallCount += 1
    }

    func detailsCount() -> Int {
        detailCallCount
    }

    func providersCount() -> Int {
        providerCallCount
    }

    func regions() -> [String?] {
        providerRegions
    }

    func collections() -> [Int] {
        collectionIDs
    }

    func recommendationsCount() -> Int {
        recommendationCallCount
    }

    func similarCount() -> Int {
        similarCallCount
    }
}
