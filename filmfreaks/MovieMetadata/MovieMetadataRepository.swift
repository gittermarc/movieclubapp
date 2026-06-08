//
//  MovieMetadataRepository.swift
//  filmfreaks
//

import Foundation

struct MovieMetadataResponse: Sendable {
    let details: TMDbMovieDetails
    let watchProvidersCountry: TMDbWatchProvidersCountry?
}

actor TMDbMetadataRepository {
    struct Dependencies: Sendable {
        var fetchMovieDetails: @Sendable (Int) async throws -> TMDbMovieDetails
        var fetchMovieWatchProviders: @Sendable (Int, String?) async throws -> TMDbWatchProvidersCountry?

        static var live: Dependencies {
            Dependencies(
                fetchMovieDetails: { id in
                    try await TMDbAPI.shared.fetchMovieDetails(id: id)
                },
                fetchMovieWatchProviders: { id, region in
                    try await TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)
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
            return MovieMetadataResponse(details: details, watchProvidersCountry: providers)

        case .quickAdd:
            let details = try await dependencies.fetchMovieDetails(movieID)
            return MovieMetadataResponse(details: details, watchProvidersCountry: nil)
        }
    }
}

typealias MovieMetadataRepository = TMDbMetadataRepository
