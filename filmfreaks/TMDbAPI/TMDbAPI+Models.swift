//
//  TMDbAPI+Models.swift
//  filmfreaks
//

import Foundation

// MARK: - API Models

struct TMDbSearchResponse: Codable {
    let page: Int
    let results: [TMDbMovieResult]
    let total_pages: Int
    let total_results: Int
}

struct TMDbMovieResult: Codable, Identifiable {
    let id: Int
    let title: String
    let release_date: String?
    let vote_average: Double
    let poster_path: String?
}

struct TMDbCredits: Decodable {
    let cast: [TMDbCast]
    let crew: [TMDbCrew]
}

struct TMDbCast: Decodable {
    /// ✅ TMDb Person ID (wichtig für Persistenz & eindeutige Zuordnung)
    let id: Int
    let name: String
    let character: String?
    /// Optionales Profilbild (kommt aus /credits; kann nil sein)
    let profile_path: String?
}

struct TMDbCrew: Decodable {
    /// ✅ TMDb Person ID (für Director-Goals)
    let id: Int
    let name: String
    let job: String?
}

struct TMDbKeyword: Decodable {
    let id: Int
    let name: String
}

struct TMDbKeywordsResponse: Decodable {
    /// Je nach Endpoint liefert TMDb entweder `keywords` oder `results`
    let keywords: [TMDbKeyword]?
    let results: [TMDbKeyword]?

    var allKeywords: [TMDbKeyword] {
        (keywords ?? []) + (results ?? [])
    }
}

struct TMDbVideo: Decodable {
    let key: String
    let name: String
    let site: String
    let type: String
}

struct TMDbVideosResponse: Decodable {
    let results: [TMDbVideo]
}

struct TMDbGenre: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
}

struct TMDbGenreListResponse: Decodable {
    let genres: [TMDbGenre]
}

struct TMDbMovieDetails: Decodable {
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

    let credits: TMDbCredits?
    let keywords: TMDbKeywordsResponse?
    let videos: TMDbVideosResponse?
    let genres: [TMDbGenre]?
}

// MARK: - Watch Providers

struct TMDbWatchProvider: Decodable, Identifiable, Hashable {
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
    let display_priority: Int?

    var id: Int { provider_id }
}

struct TMDbWatchProvidersCountry: Decodable {
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

struct TMDbWatchProvidersResponse: Decodable {
    let id: Int
    let results: [String: TMDbWatchProvidersCountry]
}

// MARK: - Personen

struct TMDbPersonSearchResponse: Decodable {
    let results: [TMDbPersonSummary]
}

struct TMDbPersonSummary: Decodable, Identifiable {
    let id: Int
    let name: String
    let profile_path: String?
    let known_for_department: String?
    let popularity: Double?
}

struct TMDbPersonDetails: Decodable {
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

struct TMDbKeywordSearchResponse: Decodable {
    let results: [TMDbKeywordSummary]
}

struct TMDbKeywordSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

// MARK: - Errors

enum TMDbError: Error {
    case missingAPIKey
    case invalidURL
    case requestFailed
    case decodingFailed
}
