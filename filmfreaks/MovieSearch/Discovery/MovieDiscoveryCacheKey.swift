//
//  MovieDiscoveryCacheKey.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieDiscoveryCacheKey {
    static func cacheKey(kind: MovieDiscoveryShelfKind, request: MovieDiscoveryRequest) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey.discoveryShelf(
            kind: kind.rawValue,
            regionCode: regionCode(for: kind, request: request),
            variant: variant(for: kind, request: request)
        )
    }

    private static func regionCode(for kind: MovieDiscoveryShelfKind, request: MovieDiscoveryRequest) -> String? {
        switch kind {
        case .nowPlaying, .preferredProviders:
            return request.regionCode
        case .personalizedRecommendations, .trending, .topRated, .popular:
            return nil
        }
    }

    private static func variant(for kind: MovieDiscoveryShelfKind, request: MovieDiscoveryRequest) -> String? {
        switch kind {
        case .personalizedRecommendations:
            let seedIDs = personalizedSeedMovies(from: request.existingWatched)
                .prefix(3)
                .compactMap(\.tmdbId)
                .map(String.init)
            guard !seedIDs.isEmpty else { return "no-seeds" }
            return "seeds-" + seedIDs.joined(separator: "-")
        case .preferredProviders:
            let ids = request.preferredProviderIDs.sorted().map(String.init)
            guard !ids.isEmpty else { return "no-providers" }
            return "providers-" + ids.joined(separator: "-") + "-flatrate-free-ads"
        case .trending:
            return TMDbTrendingTimeWindow.week.rawValue
        case .topRated, .popular, .nowPlaying:
            return nil
        }
    }

    static func personalizedSeedMovies(from watched: [Movie]) -> [Movie] {
        MovieDiscoverySeedBuilder.seedMovies(from: watched)
    }
}
