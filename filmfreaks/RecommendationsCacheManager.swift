//
//  RecommendationsCacheManager.swift
//  filmfreaks
//

import Foundation

// MARK: - ✅ Empfehlungen Cache (lokal per UserDefaults)

struct RecommendationsCacheManager {
    private static let key = "MovieSearchRecommendationsCache_v1"

    struct CachePayload: Codable {
        let timestamp: Date
        let seedTitle: String?
        let results: [TMDbMovieResult]
    }

    static func load(maxAge: TimeInterval) -> CachePayload? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data)
        else { return nil }

        if Date().timeIntervalSince(payload.timestamp) > maxAge {
            return nil
        }
        return payload
    }

    static func save(seedTitle: String?, results: [TMDbMovieResult]) {
        let payload = CachePayload(timestamp: Date(), seedTitle: seedTitle, results: results)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
