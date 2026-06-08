//
//  TMDbAPI+Details.swift
//  filmfreaks
//

import Foundation

extension TMDbAPI {

    // MARK: - Film-Details (groß, inkl. credits/keywords/videos)

    func fetchMovieDetails(id: Int) async throws -> TMDbMovieDetails {
        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE"),
            URLQueryItem(name: "append_to_response", value: "credits,keywords,videos,images,release_dates,external_ids")
        ]

        return try await requestJSON(path: "movie/\(id)", queryItems: items, type: TMDbMovieDetails.self)
    }

    // MARK: - Credits-only (kleiner, ideal für Migration)

    func fetchMovieCredits(id: Int) async throws -> TMDbCredits {
        let items: [URLQueryItem] = [
            try apiKeyQueryItem(),
            URLQueryItem(name: "language", value: "de-DE")
        ]

        return try await requestJSON(path: "movie/\(id)/credits", queryItems: items, type: TMDbCredits.self)
    }

    // MARK: - Keywords-only (kleiner)

    func fetchMovieKeywords(id: Int) async throws -> [TMDbKeyword] {
        let items: [URLQueryItem] = [
            try apiKeyQueryItem()
        ]

        let decoded = try await requestJSON(path: "movie/\(id)/keywords", queryItems: items, type: TMDbKeywordsResponse.self)
        return decoded.allKeywords
    }
}
