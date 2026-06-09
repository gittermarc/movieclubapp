//
//  TMDbAPI+Search.swift
//  filmfreaks
//

import Foundation

nonisolated enum TMDbTrendingTimeWindow: String, Codable, CaseIterable, Sendable {
    case day
    case week
}

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

    /// Aktuelle Trends auf TMDb.
    func fetchTrendingMovies(timeWindow: TMDbTrendingTimeWindow = .week, page: Int = 1) async throws -> TMDbSearchResponse {
        let safePage = max(1, page)

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        return try await requestJSON(
            path: "trending/movie/\(timeWindow.rawValue)",
            queryItems: items,
            type: TMDbSearchResponse.self
        )
    }

    /// Neue Filme im Kino für eine optionale Region.
    func fetchNowPlayingMovies(region: String? = nil, page: Int = 1) async throws -> TMDbSearchResponse {
        let safePage = max(1, page)
        let normalizedRegion = region.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }

        var items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        if let normalizedRegion {
            items.append(URLQueryItem(name: "region", value: normalizedRegion))
        }

        return try await requestJSON(path: "movie/now_playing", queryItems: items, type: TMDbSearchResponse.self)
    }

    /// Top-bewertete Filme auf TMDb.
    func fetchTopRatedMovies(page: Int = 1) async throws -> TMDbSearchResponse {
        let safePage = max(1, page)

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "page", value: String(safePage))
        ]

        return try await requestJSON(path: "movie/top_rated", queryItems: items, type: TMDbSearchResponse.self)
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
