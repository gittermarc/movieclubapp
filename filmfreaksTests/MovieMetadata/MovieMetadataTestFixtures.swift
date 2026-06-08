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
        revenue: Int? = 203_000_000
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
            belongs_to_collection: nil,
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

    func recordDetails() {
        detailCallCount += 1
    }

    func recordProvider(region: String?) {
        providerCallCount += 1
        providerRegions.append(region)
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
}
