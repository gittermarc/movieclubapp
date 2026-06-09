//
//  TMDbAPI+PeopleAndMeta.swift
//  filmfreaks
//

import Foundation

nonisolated extension TMDbAPI {

    // MARK: - Watch Providers (Streaming-Anbieter)

    /// Liefert Watch Provider Infos (Streaming/Rent/Buy) für einen Film.
    ///
    /// - Parameter region: ISO-3166-1 Ländercode (z.B. "DE").
    ///   - Wenn gesetzt: es wird *nur* dieses Land verwendet (kein stiller Fallback auf US).
    ///   - Wenn nicht gesetzt: best-effort anhand des Geräte-Landes, danach DE/US.
    func fetchMovieWatchProviders(id: Int, region: String? = nil) async throws -> TMDbWatchProvidersCountry? {
        let items: [URLQueryItem] = [
            try apiKeyQueryItem()
        ]

        let decoded = try await requestJSON(path: "movie/\(id)/watch/providers", queryItems: items, type: TMDbWatchProvidersResponse.self)

        let preferred = (region ?? TMDbAPI.preferredRegionCode())
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if let match = decoded.results[preferred] { return match }

        // Kein stiller Fallback (sonst sieht man schnell US/DE-Daten, obwohl man ein anderes Land will).
        return nil
    }


    /// Liefert den Katalog der verfügbaren Movie Watch Provider für eine optionale Region.
    func fetchMovieWatchProviderCatalog(region: String? = nil) async throws -> [TMDbWatchProvider] {
        let normalizedRegion = region.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }

        var items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        if let normalizedRegion {
            items.append(URLQueryItem(name: "watch_region", value: normalizedRegion))
        }

        let decoded = try await requestJSON(
            path: "watch/providers/movie",
            queryItems: items,
            type: TMDbWatchProvidersListResponse.self
        )
        return decoded.results
    }

    static func preferredRegionCode() -> String {
        if #available(iOS 16.0, *) {
            if let region = Locale.current.region?.identifier,
               !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return region
            }
        }

        // iOS 15 und früher: ohne deprecated `Locale.regionCode` (iOS 16+)
        if let code = (Locale.current as NSLocale).object(forKey: .countryCode) as? String,
           !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return code
        }

        return "DE"
    }

    // MARK: - Genres (für Genre-Goals)

    func fetchMovieGenreList() async throws -> [TMDbGenre] {
        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        let decoded = try await requestJSON(path: "genre/movie/list", queryItems: items, type: TMDbGenreListResponse.self)
        return decoded.genres
    }

    // MARK: - Keyword-Suche (für Keyword-Goals)

    func searchKeywords(query: String) async throws -> [TMDbKeywordSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "query", value: trimmed)
        ]

        let decoded = try await requestJSON(path: "search/keyword", queryItems: items, type: TMDbKeywordSearchResponse.self)
        return decoded.results
    }

    // MARK: - Personen

    /// Holt Detaildaten für eine Person basierend auf der TMDb-Person-ID.
    func fetchPersonDetails(id: Int) async throws -> TMDbPersonDetails {
        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        return try await requestJSON(path: "person/\(id)", queryItems: items, type: TMDbPersonDetails.self)
    }

    /// Name-Suche für Personen (Actors/Directors)
    func searchPerson(name: String) async throws -> [TMDbPersonSummary] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "include_adult", value: "false")
        ]

        let decoded = try await requestJSON(path: "search/person", queryItems: items, type: TMDbPersonSearchResponse.self)
        return decoded.results
    }
}
