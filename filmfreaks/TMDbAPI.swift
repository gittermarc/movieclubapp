//
//  TMDbAPI.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

// MARK: - API Models

struct TMDbSearchResponse: Decodable {
    let results: [TMDbMovieResult]
}

struct TMDbMovieResult: Decodable, Identifiable {
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
    let name: String
    let character: String?
}

struct TMDbCrew: Decodable {
    let name: String
    let job: String?
}

struct TMDbKeyword: Decodable {
    let name: String
}

struct TMDbKeywordsResponse: Decodable {
    let keywords: [TMDbKeyword]?
    let results: [TMDbKeyword]?   // falls TMDb das Feld anders nennt

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

struct TMDbGenre: Decodable {
    let id: Int
    let name: String
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

// MARK: - PERSON-MODELLE (NEU)

// Antwort für /search/person
struct TMDbPersonSearchResponse: Decodable {
    let results: [TMDbPersonSummary]
}

// Kurzfassung einer Person (für Suchergebnisse)
struct TMDbPersonSummary: Decodable, Identifiable {
    let id: Int
    let name: String
    let profile_path: String?
    let known_for_department: String?
    let popularity: Double?
}

// Detaildaten einer Person (für Overlay etc.)
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
    
    // MARK: - Film-Suche
    
    func searchMovies(query: String) async throws -> [TMDbMovieResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        guard !apiKey.isEmpty else {
            throw TMDbError.missingAPIKey
        }
        
        var components = URLComponents(string: "https://api.themoviedb.org/3/search/movie")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        guard let url = components?.url else {
            throw TMDbError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }
        
        do {
            let decoded = try JSONDecoder().decode(TMDbSearchResponse.self, from: data)
            return decoded.results
        } catch {
            throw TMDbError.decodingFailed
        }
    }
    
    // MARK: - Film-Details
    
    func fetchMovieDetails(id: Int) async throws -> TMDbMovieDetails {
        guard !apiKey.isEmpty else {
            throw TMDbError.missingAPIKey
        }
        
        var components = URLComponents(string: "https://api.themoviedb.org/3/movie/\(id)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "append_to_response", value: "credits,keywords,videos")
        ]
        
        guard let url = components?.url else {
            throw TMDbError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }
        
        do {
            let decoded = try JSONDecoder().decode(TMDbMovieDetails.self, from: data)
            return decoded
        } catch {
            throw TMDbError.decodingFailed
        }
    }
    
    // MARK: - PERSONEN (SCHAUSPIELER etc.) – NEU
    
    /// Sucht Personen (Schauspieler*innen, Regie etc.) nach Name.
    /// Gibt die Liste der Treffer zurück (meist reicht dir später der erste).
    func searchPerson(name: String) async throws -> [TMDbPersonSummary] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard !apiKey.isEmpty else {
            throw TMDbError.missingAPIKey
        }
        
        var components = URLComponents(string: "https://api.themoviedb.org/3/search/person")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        guard let url = components?.url else {
            throw TMDbError.invalidURL
        }
        
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
    
    /// Holt Detaildaten für eine Person basierend auf der TMDb-Person-ID.
    func fetchPersonDetails(id: Int) async throws -> TMDbPersonDetails {
        guard !apiKey.isEmpty else {
            throw TMDbError.missingAPIKey
        }
        
        var components = URLComponents(string: "https://api.themoviedb.org/3/person/\(id)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "de-DE")
            // Wenn du später mehr willst: append_to_response=combined_credits,images,external_ids etc.
        ]
        
        guard let url = components?.url else {
            throw TMDbError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }
        
        do {
            let decoded = try JSONDecoder().decode(TMDbPersonDetails.self, from: data)
            return decoded
        } catch {
            throw TMDbError.decodingFailed
        }
    }
    
    /// Komfort-Funktion: Person per Name suchen und gleich die Details holen.
    /// Nimmst du später perfekt für die tippbaren Actor-Chips in der StatsView.
    func fetchPersonDetailsByName(_ name: String) async throws -> TMDbPersonDetails? {
        let results = try await searchPerson(name: name)
        guard let first = results.first else {
            return nil
        }
        return try await fetchPersonDetails(id: first.id)
    }
}
