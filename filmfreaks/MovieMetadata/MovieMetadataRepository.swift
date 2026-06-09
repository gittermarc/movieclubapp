//
//  MovieMetadataRepository.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieMetadataResponse: Sendable {
    let details: TMDbMovieDetails
    let watchProvidersCountry: TMDbWatchProvidersCountry?
    let collectionDetails: TMDbCollectionDetails?
    let recommendations: [TMDbMovieResult]
    let recommendationsSource: MovieMetadataRecommendationSource?

    init(
        details: TMDbMovieDetails,
        watchProvidersCountry: TMDbWatchProvidersCountry?,
        collectionDetails: TMDbCollectionDetails? = nil,
        recommendations: [TMDbMovieResult] = [],
        recommendationsSource: MovieMetadataRecommendationSource? = nil
    ) {
        self.details = details
        self.watchProvidersCountry = watchProvidersCountry
        self.collectionDetails = collectionDetails
        self.recommendations = recommendations
        self.recommendationsSource = recommendationsSource
    }
}

nonisolated struct MovieMetadataRepositoryResult: Sendable {
    let response: MovieMetadataResponse
    let freshness: TMDbMetadataCacheFreshness
}

nonisolated struct MovieMetadataCachedValue<Value: Sendable>: Sendable {
    let value: Value
    let freshness: TMDbMetadataCacheFreshness
}

nonisolated struct MovieMetadataRecommendationsCachePayload: Codable, Equatable, Sendable {
    let results: [TMDbMovieResult]
    let source: MovieMetadataRecommendationSource?
}

actor TMDbMetadataRepository {
    struct Dependencies: Sendable {
        var fetchMovieDetails: @Sendable (Int) async throws -> TMDbMovieDetails
        var fetchMovieWatchProviders: @Sendable (Int, String?) async throws -> TMDbWatchProvidersCountry?
        var fetchCollectionDetails: @Sendable (Int) async throws -> TMDbCollectionDetails?
        var fetchMovieRecommendations: @Sendable (Int, Int) async throws -> TMDbSearchResponse
        var fetchMovieSimilar: @Sendable (Int, Int) async throws -> TMDbSearchResponse

        init(
            fetchMovieDetails: @escaping @Sendable (Int) async throws -> TMDbMovieDetails,
            fetchMovieWatchProviders: @escaping @Sendable (Int, String?) async throws -> TMDbWatchProvidersCountry?,
            fetchCollectionDetails: @escaping @Sendable (Int) async throws -> TMDbCollectionDetails? = { _ in nil },
            fetchMovieRecommendations: @escaping @Sendable (Int, Int) async throws -> TMDbSearchResponse = { _, _ in
                TMDbSearchResponse(page: 1, results: [], total_pages: 1, total_results: 0)
            },
            fetchMovieSimilar: @escaping @Sendable (Int, Int) async throws -> TMDbSearchResponse = { _, _ in
                TMDbSearchResponse(page: 1, results: [], total_pages: 1, total_results: 0)
            }
        ) {
            self.fetchMovieDetails = fetchMovieDetails
            self.fetchMovieWatchProviders = fetchMovieWatchProviders
            self.fetchCollectionDetails = fetchCollectionDetails
            self.fetchMovieRecommendations = fetchMovieRecommendations
            self.fetchMovieSimilar = fetchMovieSimilar
        }

        nonisolated static var live: Dependencies {
            Dependencies(
                fetchMovieDetails: { id in
                    try await TMDbAPI.shared.fetchMovieDetails(id: id)
                },
                fetchMovieWatchProviders: { id, region in
                    try await TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)
                },
                fetchCollectionDetails: { id in
                    try await TMDbAPI.shared.fetchCollectionDetails(id: id)
                },
                fetchMovieRecommendations: { id, page in
                    try await TMDbAPI.shared.fetchMovieRecommendations(id: id, page: page)
                },
                fetchMovieSimilar: { id, page in
                    try await TMDbAPI.shared.fetchMovieSimilar(id: id, page: page)
                }
            )
        }
    }

    private let dependencies: Dependencies
    private let cacheStore: TMDbMetadataCacheFileStore?
    private var inFlightMetadata: [MovieMetadataRequestKey: Task<MovieMetadataResponse, Error>] = [:]
    private var inFlightWatchProviders: [MovieMetadataWatchProvidersKey: Task<TMDbWatchProvidersCountry?, Error>] = [:]

    init(
        dependencies: Dependencies = .live,
        cacheStore: TMDbMetadataCacheFileStore? = nil
    ) {
        self.dependencies = dependencies
        self.cacheStore = cacheStore
    }

    func metadata(for movieID: Int, profile: MovieMetadataRequestProfile) async throws -> MovieMetadataResponse {
        if let cached = await cachedMetadata(for: movieID, profile: profile), cached.freshness.isUsable {
            return cached.response
        }
        return try await refreshMetadata(for: movieID, profile: profile).response
    }

    func metadataResult(for movieID: Int, profile: MovieMetadataRequestProfile) async throws -> MovieMetadataRepositoryResult {
        if let cached = await cachedMetadata(for: movieID, profile: profile), cached.freshness.isUsable {
            return cached
        }
        return try await refreshMetadata(for: movieID, profile: profile)
    }

    func cachedMetadata(for movieID: Int, profile: MovieMetadataRequestProfile) async -> MovieMetadataRepositoryResult? {
        guard let cacheStore else { return nil }

        let normalizedProfile = profile.normalizedForCache
        let detailsKey = TMDbMetadataCacheKey.movieDetails(movieID: movieID)
        guard let detailsRead = await cacheStore.read(TMDbMovieDetails.self, for: detailsKey, now: Date()),
              detailsRead.freshness.isUsable,
              let details = detailsRead.payload else {
            return nil
        }

        switch normalizedProfile {
        case .quickAdd:
            return MovieMetadataRepositoryResult(
                response: MovieMetadataResponse(details: details, watchProvidersCountry: nil),
                freshness: detailsRead.freshness
            )

        case .detailPage:
            let providersRead = await cachedWatchProviders(for: movieID, regionCode: normalizedProfile.normalizedRegionCode)
            let collectionRead = await cachedCollectionDetails(for: details.belongs_to_collection?.id)
            let recommendationsRead = await cachedRecommendations(for: movieID)

            let freshness = Self.aggregateFreshness([
                detailsRead.freshness,
                providersRead?.freshness ?? .stale,
                collectionRead?.freshness ?? (details.belongs_to_collection == nil ? .fresh : .stale),
                recommendationsRead?.freshness ?? .stale
            ])

            return MovieMetadataRepositoryResult(
                response: MovieMetadataResponse(
                    details: details,
                    watchProvidersCountry: providersRead?.value,
                    collectionDetails: collectionRead?.value,
                    recommendations: recommendationsRead?.value.results ?? [],
                    recommendationsSource: recommendationsRead?.value.source
                ),
                freshness: freshness
            )
        }
    }

    func refreshMetadata(for movieID: Int, profile: MovieMetadataRequestProfile) async throws -> MovieMetadataRepositoryResult {
        let normalizedProfile = profile.normalizedForCache
        let key = MovieMetadataRequestKey(movieID: movieID, profile: normalizedProfile)
        if let task = inFlightMetadata[key] {
            let response = try await task.value
            return MovieMetadataRepositoryResult(response: response, freshness: .fresh)
        }

        let dependencies = dependencies
        let cacheStore = cacheStore
        let task = Task {
            try await Self.fetchMetadata(
                movieID: movieID,
                profile: normalizedProfile,
                dependencies: dependencies,
                cacheStore: cacheStore
            )
        }

        inFlightMetadata[key] = task
        defer { inFlightMetadata[key] = nil }
        let response = try await task.value
        return MovieMetadataRepositoryResult(response: response, freshness: .fresh)
    }

    func watchProviders(for movieID: Int, regionCode: String?) async throws -> TMDbWatchProvidersCountry? {
        if let cached = await cachedWatchProviders(for: movieID, regionCode: regionCode), cached.freshness.isUsable {
            return cached.value
        }
        return try await refreshWatchProviders(for: movieID, regionCode: regionCode).value
    }

    func cachedWatchProviders(
        for movieID: Int,
        regionCode: String?
    ) async -> MovieMetadataCachedValue<TMDbWatchProvidersCountry?>? {
        guard let cacheStore else { return nil }
        let normalizedRegionCode = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
        let key = TMDbMetadataCacheKey.watchProviders(movieID: movieID, regionCode: normalizedRegionCode)
        guard let read = await cacheStore.read(TMDbWatchProvidersCountry.self, for: key, now: Date()), read.freshness.isUsable else {
            return nil
        }
        return MovieMetadataCachedValue(value: read.payload, freshness: read.freshness)
    }

    func refreshWatchProviders(
        for movieID: Int,
        regionCode: String?
    ) async throws -> MovieMetadataCachedValue<TMDbWatchProvidersCountry?> {
        let normalizedRegionCode = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
        let key = MovieMetadataWatchProvidersKey(movieID: movieID, regionCode: normalizedRegionCode)
        if let task = inFlightWatchProviders[key] {
            return MovieMetadataCachedValue(value: try await task.value, freshness: .fresh)
        }

        let dependencies = dependencies
        let cacheStore = cacheStore
        let task = Task {
            try await Self.fetchAndCacheWatchProviders(
                movieID: movieID,
                regionCode: normalizedRegionCode,
                dependencies: dependencies,
                cacheStore: cacheStore
            )
        }

        inFlightWatchProviders[key] = task
        defer { inFlightWatchProviders[key] = nil }
        return MovieMetadataCachedValue(value: try await task.value, freshness: .fresh)
    }

    private func cachedCollectionDetails(for collectionID: Int?) async -> MovieMetadataCachedValue<TMDbCollectionDetails?>? {
        guard let cacheStore, let collectionID else { return nil }
        let key = TMDbMetadataCacheKey.collectionDetails(collectionID: collectionID)
        guard let read = await cacheStore.read(TMDbCollectionDetails.self, for: key, now: Date()), read.freshness.isUsable else {
            return nil
        }
        return MovieMetadataCachedValue(value: read.payload, freshness: read.freshness)
    }

    private func cachedRecommendations(for movieID: Int) async -> MovieMetadataCachedValue<MovieMetadataRecommendationsCachePayload>? {
        guard let cacheStore else { return nil }
        let key = TMDbMetadataCacheKey.recommendations(movieID: movieID)
        guard let read = await cacheStore.read(MovieMetadataRecommendationsCachePayload.self, for: key, now: Date()), read.freshness.isUsable else {
            return nil
        }
        if let payload = read.payload {
            return MovieMetadataCachedValue(value: payload, freshness: read.freshness)
        }
        return MovieMetadataCachedValue(
            value: MovieMetadataRecommendationsCachePayload(results: [], source: nil),
            freshness: read.freshness
        )
    }

    private static func fetchMetadata(
        movieID: Int,
        profile: MovieMetadataRequestProfile,
        dependencies: Dependencies,
        cacheStore: TMDbMetadataCacheFileStore?
    ) async throws -> MovieMetadataResponse {
        switch profile {
        case .detailPage:
            async let detailsTask = dependencies.fetchMovieDetails(movieID)
            async let providersTask = fetchAndCacheWatchProviders(
                movieID: movieID,
                regionCode: profile.normalizedRegionCode,
                dependencies: dependencies,
                cacheStore: cacheStore
            )

            let details = try await detailsTask
            await cacheStore?.write(
                details,
                for: .movieDetails(movieID: movieID),
                policy: .movieDetails,
                now: Date(),
                isNegative: false
            )

            let providers = try? await providersTask

            async let collectionTask = fetchAndCacheCollectionDetailsIfAvailable(
                summary: details.belongs_to_collection,
                dependencies: dependencies,
                cacheStore: cacheStore
            )
            async let recommendationsTask = fetchAndCacheRecommendations(
                movieID: movieID,
                dependencies: dependencies,
                cacheStore: cacheStore
            )

            let collectionDetails = await collectionTask
            let recommendationPayload = await recommendationsTask

            return MovieMetadataResponse(
                details: details,
                watchProvidersCountry: providers,
                collectionDetails: collectionDetails,
                recommendations: recommendationPayload.results,
                recommendationsSource: recommendationPayload.source
            )

        case .quickAdd:
            let details = try await dependencies.fetchMovieDetails(movieID)
            await cacheStore?.write(
                details,
                for: .movieDetails(movieID: movieID),
                policy: .movieDetails,
                now: Date(),
                isNegative: false
            )
            return MovieMetadataResponse(details: details, watchProvidersCountry: nil)
        }
    }

    private static func fetchAndCacheWatchProviders(
        movieID: Int,
        regionCode: String?,
        dependencies: Dependencies,
        cacheStore: TMDbMetadataCacheFileStore?
    ) async throws -> TMDbWatchProvidersCountry? {
        do {
            let providers = try await dependencies.fetchMovieWatchProviders(movieID, regionCode)
            await cacheStore?.write(
                providers,
                for: .watchProviders(movieID: movieID, regionCode: regionCode),
                policy: providers == nil ? .negativeWatchProviders : .watchProviders,
                now: Date(),
                isNegative: providers == nil
            )
            return providers
        } catch TMDbError.missingAPIKey {
            throw TMDbError.missingAPIKey
        } catch {
            await cacheStore?.write(
                Optional<TMDbWatchProvidersCountry>.none,
                for: .watchProviders(movieID: movieID, regionCode: regionCode),
                policy: .negativeWatchProviders,
                now: Date(),
                isNegative: true
            )
            throw error
        }
    }

    private static func fetchAndCacheCollectionDetailsIfAvailable(
        summary: TMDbCollectionSummary?,
        dependencies: Dependencies,
        cacheStore: TMDbMetadataCacheFileStore?
    ) async -> TMDbCollectionDetails? {
        guard let summary else { return nil }
        do {
            let details = try await dependencies.fetchCollectionDetails(summary.id)
            if let details {
                await cacheStore?.write(
                    details,
                    for: .collectionDetails(collectionID: summary.id),
                    policy: .collectionDetails,
                    now: Date(),
                    isNegative: false
                )
            }
            return details
        } catch {
            return nil
        }
    }

    private static func fetchAndCacheRecommendations(
        movieID: Int,
        dependencies: Dependencies,
        cacheStore: TMDbMetadataCacheFileStore?
    ) async -> MovieMetadataRecommendationsCachePayload {
        do {
            let recommendations = try await dependencies.fetchMovieRecommendations(movieID, 1).results
            if !recommendations.isEmpty {
                let payload = MovieMetadataRecommendationsCachePayload(results: recommendations, source: .recommendations)
                await cacheStore?.write(
                    payload,
                    for: .recommendations(movieID: movieID),
                    policy: .recommendations,
                    now: Date(),
                    isNegative: false
                )
                return payload
            }

            let similar = try await dependencies.fetchMovieSimilar(movieID, 1).results
            if !similar.isEmpty {
                let payload = MovieMetadataRecommendationsCachePayload(results: similar, source: .similar)
                await cacheStore?.write(
                    payload,
                    for: .recommendations(movieID: movieID),
                    policy: .recommendations,
                    now: Date(),
                    isNegative: false
                )
                return payload
            }

            return await cacheNegativeRecommendations(movieID: movieID, cacheStore: cacheStore)
        } catch TMDbError.missingAPIKey {
            return MovieMetadataRecommendationsCachePayload(results: [], source: nil)
        } catch {
            return await cacheNegativeRecommendations(movieID: movieID, cacheStore: cacheStore)
        }
    }

    private static func cacheNegativeRecommendations(
        movieID: Int,
        cacheStore: TMDbMetadataCacheFileStore?
    ) async -> MovieMetadataRecommendationsCachePayload {
        let payload = MovieMetadataRecommendationsCachePayload(results: [], source: nil)
        await cacheStore?.write(
            payload,
            for: .recommendations(movieID: movieID),
            policy: .negativeRecommendations,
            now: Date(),
            isNegative: true
        )
        return payload
    }

    private static func aggregateFreshness(_ values: [TMDbMetadataCacheFreshness]) -> TMDbMetadataCacheFreshness {
        if values.contains(.expired) { return .expired }
        if values.contains(.stale) { return .stale }
        return .fresh
    }
}

typealias MovieMetadataRepository = TMDbMetadataRepository
