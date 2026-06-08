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

        static var live: Dependencies {
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
    private var inFlightMetadata: [MovieMetadataRequestKey: Task<MovieMetadataResponse, Error>] = [:]
    private var inFlightWatchProviders: [MovieMetadataWatchProvidersKey: Task<TMDbWatchProvidersCountry?, Error>] = [:]

    init(dependencies: Dependencies = .live) {
        self.dependencies = dependencies
    }

    func metadata(for movieID: Int, profile: MovieMetadataRequestProfile) async throws -> MovieMetadataResponse {
        let normalizedProfile = profile.normalizedForCache
        let key = MovieMetadataRequestKey(movieID: movieID, profile: normalizedProfile)
        if let task = inFlightMetadata[key] {
            return try await task.value
        }

        let dependencies = dependencies
        let task = Task {
            try await Self.fetchMetadata(
                movieID: movieID,
                profile: normalizedProfile,
                dependencies: dependencies
            )
        }

        inFlightMetadata[key] = task
        defer { inFlightMetadata[key] = nil }
        return try await task.value
    }

    func watchProviders(for movieID: Int, regionCode: String?) async throws -> TMDbWatchProvidersCountry? {
        let normalizedRegionCode = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
        let key = MovieMetadataWatchProvidersKey(movieID: movieID, regionCode: normalizedRegionCode)
        if let task = inFlightWatchProviders[key] {
            return try await task.value
        }

        let dependencies = dependencies
        let task = Task {
            try await dependencies.fetchMovieWatchProviders(movieID, normalizedRegionCode)
        }

        inFlightWatchProviders[key] = task
        defer { inFlightWatchProviders[key] = nil }
        return try await task.value
    }

    private static func fetchMetadata(
        movieID: Int,
        profile: MovieMetadataRequestProfile,
        dependencies: Dependencies
    ) async throws -> MovieMetadataResponse {
        switch profile {
        case .detailPage:
            async let detailsTask = dependencies.fetchMovieDetails(movieID)
            async let providersTask = dependencies.fetchMovieWatchProviders(movieID, profile.normalizedRegionCode)

            let details = try await detailsTask
            let providers = try? await providersTask

            async let collectionTask = fetchCollectionDetailsIfAvailable(
                summary: details.belongs_to_collection,
                dependencies: dependencies
            )
            async let recommendationsTask = fetchRecommendations(
                movieID: movieID,
                dependencies: dependencies
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
            return MovieMetadataResponse(details: details, watchProvidersCountry: nil)
        }
    }

    private static func fetchCollectionDetailsIfAvailable(
        summary: TMDbCollectionSummary?,
        dependencies: Dependencies
    ) async -> TMDbCollectionDetails? {
        guard let summary else { return nil }
        return try? await dependencies.fetchCollectionDetails(summary.id)
    }

    private static func fetchRecommendations(
        movieID: Int,
        dependencies: Dependencies
    ) async -> (results: [TMDbMovieResult], source: MovieMetadataRecommendationSource?) {
        do {
            let recommendations = try await dependencies.fetchMovieRecommendations(movieID, 1).results
            if !recommendations.isEmpty {
                return (recommendations, .recommendations)
            }

            let similar = try await dependencies.fetchMovieSimilar(movieID, 1).results
            if !similar.isEmpty {
                return (similar, .similar)
            }
        } catch {
            return ([], nil)
        }

        return ([], nil)
    }
}

typealias MovieMetadataRepository = TMDbMetadataRepository
