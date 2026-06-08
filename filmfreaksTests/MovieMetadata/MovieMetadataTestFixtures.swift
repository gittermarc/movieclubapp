import Foundation
@testable import filmfreaks

enum MovieMetadataTestFixtures {
    static func makeDetails(
        id: Int = 42,
        title: String = "Arrival",
        voteAverage: Double = 8.4,
        posterPath: String? = "/poster.jpg",
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
        )
    ) -> TMDbMovieDetails {
        TMDbMovieDetails(
            id: id,
            title: title,
            tagline: "Why are they here?",
            overview: "Aliens arrive.",
            release_date: "2016-11-10",
            original_title: title,
            original_language: "en",
            runtime: 116,
            vote_average: voteAverage,
            poster_path: posterPath,
            credits: credits,
            keywords: keywords,
            videos: TMDbVideosResponse(results: []),
            genres: genres,
            backdrop_path: "/backdrop.jpg",
            belongs_to_collection: nil,
            images: TMDbMovieImagesResponse(backdrops: [], logos: [], posters: []),
            release_dates: TMDbReleaseDatesResponse(results: []),
            external_ids: TMDbExternalIDs(
                imdb_id: "tt2543164",
                wikidata_id: nil,
                facebook_id: nil,
                instagram_id: nil,
                twitter_id: nil
            ),
            production_companies: [
                TMDbProductionCompany(
                    id: 1,
                    logo_path: nil,
                    name: "FilmNation Entertainment",
                    origin_country: "US"
                )
            ],
            production_countries: [
                TMDbProductionCountry(iso_3166_1: "US", name: "United States of America")
            ],
            spoken_languages: [
                TMDbSpokenLanguage(english_name: "English", iso_639_1: "en", name: "English")
            ],
            status: "Released",
            homepage: "https://example.com/arrival",
            budget: 47_000_000,
            revenue: 203_000_000
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
