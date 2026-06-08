//
//  TMDbAPI+Search.swift
//  filmfreaks
//

import Foundation

nonisolated extension TMDbAPI {

    // MARK: - Film-Suche (paged)

    /// Paged Search: liefert page + total_pages + total_results
    func searchMoviesPaged(query: String, page: Int = 1) async throws -> TMDbSearchResponse {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return TMDbSearchResponse(page: 1, results: [], total_pages: 1, total_results: 0)
        }

        let safePage = max(1, page)

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "query", value: trimmedQuery),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        return try await requestJSON(path: "search/movie", queryItems: items, type: TMDbSearchResponse.self)
    }

    /// Backwards-compatible: wie vorher, nur Seite 1 als Array
    func searchMovies(query: String) async throws -> [TMDbMovieResult] {
        let response = try await searchMoviesPaged(query: query, page: 1)
        return response.results
    }

    // MARK: - Empfehlungen / Similar (für Inspiration)

    /// Beliebte Filme (Fallback, wenn noch keine Seeds vorhanden sind).
    func fetchPopularMovies(page: Int = 1) async throws -> TMDbSearchResponse {
        let safePage = max(1, page)

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        return try await requestJSON(path: "movie/popular", queryItems: items, type: TMDbSearchResponse.self)
    }

    /// Empfehlungen basierend auf einem Film (TMDb /recommendations).
    func fetchMovieRecommendations(id: Int, page: Int = 1) async throws -> TMDbSearchResponse {
        let safePage = max(1, page)

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        return try await requestJSON(path: "movie/\(id)/recommendations", queryItems: items, type: TMDbSearchResponse.self)
    }

    /// Ähnliche Filme (Fallback, falls Recommendations leer sind).
    func fetchMovieSimilar(id: Int, page: Int = 1) async throws -> TMDbSearchResponse {
        let safePage = max(1, page)

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        return try await requestJSON(path: "movie/\(id)/similar", queryItems: items, type: TMDbSearchResponse.self)
    }
}
