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

    let credits: TMDbCredits?             // NEU
    let keywords: TMDbKeywordsResponse?   // NEU
    let videos: TMDbVideosResponse?       // NEU
    let genres: [TMDbGenre]?      // NEU
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
    
    // TODO: Deinen echten API Key hier eintragen
    private let apiKey: String = "efb878777c3bf57a2d6e8710061cc945"
    
    private init() {}
    
    // Suche nach Filmen
    func searchMovies(query: String) async throws -> [TMDbMovieResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        guard apiKey != "" else {
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
    
    // Details für einen konkreten Film
    func fetchMovieDetails(id: Int) async throws -> TMDbMovieDetails {
        guard apiKey != "DEIN_TMDB_API_KEY_HIER" else {
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
}
