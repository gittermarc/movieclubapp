//
//  WatchProviderCatalogRepository.swift
//  filmfreaks
//

import Foundation

actor WatchProviderCatalogRepository {
    struct Dependencies: Sendable {
        var fetchMovieWatchProviderCatalog: @Sendable (String?) async throws -> [TMDbWatchProvider]
        var now: @Sendable () -> Date

        init(
            fetchMovieWatchProviderCatalog: @escaping @Sendable (String?) async throws -> [TMDbWatchProvider],
            now: @escaping @Sendable () -> Date = { Date() }
        ) {
            self.fetchMovieWatchProviderCatalog = fetchMovieWatchProviderCatalog
            self.now = now
        }

        nonisolated static var live: Dependencies {
            Dependencies(
                fetchMovieWatchProviderCatalog: { region in
                    try await TMDbAPI.shared.fetchMovieWatchProviderCatalog(region: region)
                },
                now: { Date() }
            )
        }
    }

    private let dependencies: Dependencies
    private let cacheStore: TMDbMetadataCacheFileStore?

    init(
        dependencies: Dependencies = .live,
        cacheStore: TMDbMetadataCacheFileStore? = TMDbMetadataCacheFileStore()
    ) {
        self.dependencies = dependencies
        self.cacheStore = cacheStore
    }

    func providers(regionCode: String?, forceRefresh: Bool = false) async throws -> [TMDbWatchProvider] {
        let normalizedRegion = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
        let key = TMDbMetadataCacheKey.watchProviderCatalog(regionCode: normalizedRegion)

        if !forceRefresh,
           let cached = await cacheStore?.read([TMDbWatchProvider].self, for: key, now: dependencies.now()),
           cached.freshness.isUsable,
           let payload = cached.payload {
            return payload
        }

        let providers = try await dependencies.fetchMovieWatchProviderCatalog(normalizedRegion)
        await cacheStore?.write(
            providers,
            for: key,
            policy: .watchProviderCatalog,
            now: dependencies.now(),
            isNegative: false
        )
        return providers
    }
}
