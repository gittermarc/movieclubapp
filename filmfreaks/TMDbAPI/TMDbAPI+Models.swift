//
//  TMDbAPI+Models.swift
//  filmfreaks
//

import Foundation

// MARK: - API Models

struct TMDbSearchResponse: Codable, Sendable {
    let page: Int
    let results: [TMDbMovieResult]
    let total_pages: Int
    let total_results: Int
}

struct TMDbMovieResult: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let release_date: String?
    let vote_average: Double
    let poster_path: String?
    let backdrop_path: String?

    init(
        id: Int,
        title: String,
        release_date: String?,
        vote_average: Double,
        poster_path: String?,
        backdrop_path: String? = nil
    ) {
        self.id = id
        self.title = title
        self.release_date = release_date
        self.vote_average = vote_average
        self.poster_path = poster_path
        self.backdrop_path = backdrop_path
    }
}

struct TMDbCredits: Decodable, Sendable {
    let cast: [TMDbCast]
    let crew: [TMDbCrew]
}

struct TMDbCast: Decodable, Sendable {
    /// ✅ TMDb Person ID (wichtig für Persistenz & eindeutige Zuordnung)
    let id: Int
    let name: String
    /// Popularity wird in Credits/Details Responses typischerweise mitgeliefert.
    /// Optional & backwards-compatible (wenn ein Endpoint es nicht sendet).
    let popularity: Double?
    let character: String?
    /// Optionales Profilbild (kommt aus /credits; kann nil sein)
    let profile_path: String?
}

struct TMDbCrew: Decodable, Sendable {
    /// ✅ TMDb Person ID (für Director-Goals)
    let id: Int
    let name: String
    /// Popularity wird in Credits/Details Responses typischerweise mitgeliefert.
    /// Optional & backwards-compatible (wenn ein Endpoint es nicht sendet).
    let popularity: Double?
    let job: String?
}

struct TMDbKeyword: Decodable, Sendable {
    let id: Int
    let name: String
}

struct TMDbKeywordsResponse: Decodable, Sendable {
    /// Je nach Endpoint liefert TMDb entweder `keywords` oder `results`
    let keywords: [TMDbKeyword]?
    let results: [TMDbKeyword]?

    var allKeywords: [TMDbKeyword] {
        (keywords ?? []) + (results ?? [])
    }
}

struct TMDbVideo: Decodable, Sendable {
    let key: String
    let name: String
    let site: String
    let type: String
}

struct TMDbVideosResponse: Decodable, Sendable {
    let results: [TMDbVideo]
}

struct TMDbGenre: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
}

struct TMDbGenreListResponse: Decodable, Sendable {
    let genres: [TMDbGenre]
}

struct TMDbCollectionSummary: Decodable, Equatable, Sendable {
    let id: Int
    let name: String
    let poster_path: String?
    let backdrop_path: String?
}

struct TMDbImage: Decodable, Hashable, Sendable {
    let aspect_ratio: Double?
    let height: Int?
    let iso_639_1: String?
    let file_path: String
    let vote_average: Double?
    let vote_count: Int?
    let width: Int?
}

struct TMDbMovieImagesResponse: Decodable, Sendable {
    let backdrops: [TMDbImage]
    let logos: [TMDbImage]
    let posters: [TMDbImage]
}

struct TMDbReleaseDate: Decodable, Sendable {
    let certification: String
    let descriptors: [String]?
    let iso_639_1: String?
    let note: String?
    let release_date: String
    let type: Int
}

struct TMDbReleaseDatesCountry: Decodable, Sendable {
    let iso_3166_1: String
    let release_dates: [TMDbReleaseDate]
}

struct TMDbReleaseDatesResponse: Decodable, Sendable {
    let results: [TMDbReleaseDatesCountry]
}

struct TMDbExternalIDs: Decodable, Sendable {
    let imdb_id: String?
    let wikidata_id: String?
    let facebook_id: String?
    let instagram_id: String?
    let twitter_id: String?
}

struct TMDbProductionCompany: Decodable, Identifiable, Sendable {
    let id: Int
    let logo_path: String?
    let name: String
    let origin_country: String?
}

struct TMDbProductionCountry: Decodable, Hashable, Sendable {
    let iso_3166_1: String
    let name: String
}

struct TMDbSpokenLanguage: Decodable, Hashable, Sendable {
    let english_name: String?
    let iso_639_1: String
    let name: String
}

struct TMDbMovieDetails: Decodable, Sendable {
    let id: Int
    let title: String

    // ✅ Quick Wins: mehr Details
    let tagline: String?
    let overview: String?
    let release_date: String?
    let original_title: String?
    let original_language: String?

    let runtime: Int?
    let vote_average: Double
    let poster_path: String?
    let backdrop_path: String?
    let belongs_to_collection: TMDbCollectionSummary?

    let budget: Int?
    let revenue: Int?
    let homepage: String?
    let status: String?
    let production_companies: [TMDbProductionCompany]?
    let production_countries: [TMDbProductionCountry]?
    let spoken_languages: [TMDbSpokenLanguage]?

    let credits: TMDbCredits?
    let keywords: TMDbKeywordsResponse?
    let videos: TMDbVideosResponse?
    let images: TMDbMovieImagesResponse?
    let release_dates: TMDbReleaseDatesResponse?
    let external_ids: TMDbExternalIDs?
    let genres: [TMDbGenre]?

    init(
        id: Int,
        title: String,
        tagline: String? = nil,
        overview: String? = nil,
        release_date: String? = nil,
        original_title: String? = nil,
        original_language: String? = nil,
        runtime: Int? = nil,
        vote_average: Double,
        poster_path: String? = nil,
        credits: TMDbCredits? = nil,
        keywords: TMDbKeywordsResponse? = nil,
        videos: TMDbVideosResponse? = nil,
        genres: [TMDbGenre]? = nil,
        backdrop_path: String? = nil,
        belongs_to_collection: TMDbCollectionSummary? = nil,
        images: TMDbMovieImagesResponse? = nil,
        release_dates: TMDbReleaseDatesResponse? = nil,
        external_ids: TMDbExternalIDs? = nil,
        production_companies: [TMDbProductionCompany]? = nil,
        production_countries: [TMDbProductionCountry]? = nil,
        spoken_languages: [TMDbSpokenLanguage]? = nil,
        status: String? = nil,
        homepage: String? = nil,
        budget: Int? = nil,
        revenue: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.tagline = tagline
        self.overview = overview
        self.release_date = release_date
        self.original_title = original_title
        self.original_language = original_language
        self.runtime = runtime
        self.vote_average = vote_average
        self.poster_path = poster_path
        self.backdrop_path = backdrop_path
        self.belongs_to_collection = belongs_to_collection
        self.budget = budget
        self.revenue = revenue
        self.homepage = homepage
        self.status = status
        self.production_companies = production_companies
        self.production_countries = production_countries
        self.spoken_languages = spoken_languages
        self.credits = credits
        self.keywords = keywords
        self.videos = videos
        self.images = images
        self.release_dates = release_dates
        self.external_ids = external_ids
        self.genres = genres
    }
}

// MARK: - Watch Providers

struct TMDbWatchProvider: Decodable, Identifiable, Hashable, Sendable {
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
    let display_priority: Int?

    var id: Int { provider_id }
}

struct TMDbWatchProvidersCountry: Decodable, Sendable {
    let link: String?

    /// Subscription streaming services ("flatrate" in TMDb)
    let flatrate: [TMDbWatchProvider]?

    /// Ad-supported streaming services
    let ads: [TMDbWatchProvider]?

    /// Free streaming services
    let free: [TMDbWatchProvider]?

    /// Rental offers
    let rent: [TMDbWatchProvider]?

    /// Buy offers
    let buy: [TMDbWatchProvider]?
}

struct TMDbWatchProvidersResponse: Decodable, Sendable {
    let id: Int
    let results: [String: TMDbWatchProvidersCountry]
}

// MARK: - Personen

struct TMDbPersonSearchResponse: Decodable, Sendable {
    let results: [TMDbPersonSummary]
}

struct TMDbPersonSummary: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let profile_path: String?
    let known_for_department: String?
    let popularity: Double?
}

struct TMDbPersonDetails: Decodable, Sendable {
    let id: Int
    let name: String
    let biography: String?
    let birthday: String?
    let deathday: String?
    let place_of_birth: String?
    let profile_path: String?
    let homepage: String?
    let known_for_department: String?
    let also_known_as: [String]?
    let popularity: Double?
}

// MARK: - Keyword Search

struct TMDbKeywordSearchResponse: Decodable, Sendable {
    let results: [TMDbKeywordSummary]
}

struct TMDbKeywordSummary: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

// MARK: - Errors

enum TMDbError: Error, Sendable {
    case missingAPIKey
    case invalidURL
    case requestFailed
    case decodingFailed
}
