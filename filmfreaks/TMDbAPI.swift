//
//  TMDbAPI.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
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
    let overview: String?
    let release_date: String?
    let runtime: Int?
    let vote_average: Double
    let poster_path: String?

    let credits: TMDbCredits?
    let keywords: TMDbKeywordsResponse?
    let videos: TMDbVideosResponse?
    let genres: [TMDbGenre]?
}

// MARK: - PERSON-MODELLE

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

// MARK: - KEYWORD SEARCH

struct TMDbKeywordSearchResponse: Decodable {
    let results: [TMDbKeywordSummary]
}

struct TMDbKeywordSummary: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

enum TMDbError: Error {
    case missingAPIKey
    case invalidURL
    case requestFailed
    case decodingFailed
}

// MARK: - API Client

final class TMDbAPI {

    static let shared = TMDbAPI()

    // Deinen API-Key hier
    private let apiKey: String = "efb878777c3bf57a2d6e8710061cc945"

    private init() {}

    // MARK: - Film-Suche (paged)

    /// Paged Search: liefert page + total_pages + total_results
    func searchMoviesPaged(query: String, page: Int = 1) async throws -> TMDbSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return TMDbSearchResponse(page: 1, results: [], total_pages: 1, total_results: 0)
        }
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }
        let safePage = max(1, page)

        var components = URLComponents(string: "https://api.themoviedb.org/3/search/movie")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    /// Backwards-compatible: wie vorher, nur Seite 1 als Array
    func searchMovies(query: String) async throws -> [TMDbMovieResult] {
        let response = try await searchMoviesPaged(query: query, page: 1)
        return response.results
    }

    // MARK: - Empfehlungen / Similar (für Inspiration)


    /// Beliebte Filme (Fallback, wenn noch keine Seeds vorhanden sind).
    func fetchPopularMovies(page: Int = 1) async throws -> TMDbSearchResponse {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }
        let safePage = max(1, page)

        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/popular")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    /// Empfehlungen basierend auf einem Film (TMDb /recommendations).
    func fetchMovieRecommendations(id: Int, page: Int = 1) async throws -> TMDbSearchResponse {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }
        let safePage = max(1, page)

        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(id)/recommendations")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    /// Ähnliche Filme (Fallback, falls Recommendations leer sind).
    func fetchMovieSimilar(id: Int, page: Int = 1) async throws -> TMDbSearchResponse {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }
        let safePage = max(1, page)

        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(id)/similar")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    // MARK: - Film-Details (groß, inkl. credits/keywords/videos)

    func fetchMovieDetails(id: Int) async throws -> TMDbMovieDetails {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(id)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "append_to_response", value: "credits,keywords,videos")
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbMovieDetails.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    // MARK: - Credits-only (kleiner, ideal für Migration)

    func fetchMovieCredits(id: Int) async throws -> TMDbCredits {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(id)/credits")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbCredits.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    // MARK: - Keywords-only (kleiner)

    func fetchMovieKeywords(id: Int) async throws -> [TMDbKeyword] {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(id)/keywords")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            let decoded = try JSONDecoder().decode(TMDbKeywordsResponse.self, from: data)
            return decoded.allKeywords
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    // MARK: - Genres (für Genre-Goals)

    func fetchMovieGenreList() async throws -> [TMDbGenre] {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/genre/movie/list")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            let decoded = try JSONDecoder().decode(TMDbGenreListResponse.self, from: data)
            return decoded.genres
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    // MARK: - Keyword-Suche (für Keyword-Goals)

    func searchKeywords(query: String) async throws -> [TMDbKeywordSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/search/keyword")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed)
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            let decoded = try JSONDecoder().decode(TMDbKeywordSearchResponse.self, from: data)
            return decoded.results
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    // MARK: - PERSONEN

    /// Holt Detaildaten für eine Person basierend auf der TMDb-Person-ID.
    func fetchPersonDetails(id: Int) async throws -> TMDbPersonDetails {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/person/\(id)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            return try JSONDecoder().decode(TMDbPersonDetails.self, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    /// Name-Suche für Personen (Actors/Directors)
    func searchPerson(name: String) async throws -> [TMDbPersonSummary] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3/search/person")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "include_adult", value: "false")
        ]

        guard let url = components?.url else { throw TMDbError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }

        do {
            let decoded = try JSONDecoder().decode(TMDbPersonSearchResponse.self, from: data)
            return decoded.results
        } catch {
            throw TMDbError.decodingFailed
        }
    }
}
