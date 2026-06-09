//
//  MovieDiscoveryService.swift
//  filmfreaks
//

import Foundation

actor MovieDiscoveryService {
    struct Dependencies {
        var fetchTrendingMovies: (TMDbTrendingTimeWindow, Int) async throws -> TMDbSearchResponse
        var fetchNowPlayingMovies: (String?, Int) async throws -> TMDbSearchResponse
        var fetchTopRatedMovies: (Int) async throws -> TMDbSearchResponse
        var fetchPopularMovies: (Int) async throws -> TMDbSearchResponse
        var fetchMovieRecommendations: (Int, Int) async throws -> TMDbSearchResponse
        var fetchMovieSimilar: (Int, Int) async throws -> TMDbSearchResponse
        var fetchDiscoverMoviesWithWatchProviders: (String?, [Int], [String], Int) async throws -> TMDbSearchResponse
        var now: () -> Date

        init(
            fetchTrendingMovies: @escaping (TMDbTrendingTimeWindow, Int) async throws -> TMDbSearchResponse,
            fetchNowPlayingMovies: @escaping (String?, Int) async throws -> TMDbSearchResponse,
            fetchTopRatedMovies: @escaping (Int) async throws -> TMDbSearchResponse,
            fetchPopularMovies: @escaping (Int) async throws -> TMDbSearchResponse,
            fetchMovieRecommendations: @escaping (Int, Int) async throws -> TMDbSearchResponse,
            fetchMovieSimilar: @escaping (Int, Int) async throws -> TMDbSearchResponse,
            fetchDiscoverMoviesWithWatchProviders: @escaping (String?, [Int], [String], Int) async throws -> TMDbSearchResponse = { _, _, _, _ in
                TMDbSearchResponse(page: 1, results: [], total_pages: 1, total_results: 0)
            },
            now: @escaping () -> Date = { Date() }
        ) {
            self.fetchTrendingMovies = fetchTrendingMovies
            self.fetchNowPlayingMovies = fetchNowPlayingMovies
            self.fetchTopRatedMovies = fetchTopRatedMovies
            self.fetchPopularMovies = fetchPopularMovies
            self.fetchMovieRecommendations = fetchMovieRecommendations
            self.fetchMovieSimilar = fetchMovieSimilar
            self.fetchDiscoverMoviesWithWatchProviders = fetchDiscoverMoviesWithWatchProviders
            self.now = now
        }

        nonisolated static var live: Dependencies {
            Dependencies(
                fetchTrendingMovies: { timeWindow, page in
                    try await TMDbAPI.shared.fetchTrendingMovies(timeWindow: timeWindow, page: page)
                },
                fetchNowPlayingMovies: { region, page in
                    try await TMDbAPI.shared.fetchNowPlayingMovies(region: region, page: page)
                },
                fetchTopRatedMovies: { page in
                    try await TMDbAPI.shared.fetchTopRatedMovies(page: page)
                },
                fetchPopularMovies: { page in
                    try await TMDbAPI.shared.fetchPopularMovies(page: page)
                },
                fetchMovieRecommendations: { id, page in
                    try await TMDbAPI.shared.fetchMovieRecommendations(id: id, page: page)
                },
                fetchMovieSimilar: { id, page in
                    try await TMDbAPI.shared.fetchMovieSimilar(id: id, page: page)
                },
                fetchDiscoverMoviesWithWatchProviders: { region, providerIDs, monetizationTypes, page in
                    try await TMDbAPI.shared.fetchDiscoverMoviesWithWatchProviders(
                        region: region,
                        providerIDs: providerIDs,
                        monetizationTypes: monetizationTypes,
                        page: page
                    )
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

    func loadShelves(
        request: MovieDiscoveryRequest,
        kinds: [MovieDiscoveryShelfKind] = MovieDiscoveryShelfKind.allCases,
        forceRefresh: Bool = false
    ) async -> MovieDiscoveryLoadResult {
        var shelves: [MovieDiscoveryShelf] = []
        var usedStaleCache = false

        for kind in kinds {
            let load = await loadShelf(kind: kind, request: request, forceRefresh: forceRefresh)
            if load.usedStaleCache { usedStaleCache = true }
            shelves.append(load.shelf)
        }

        return MovieDiscoveryLoadResult(shelves: shelves, usedStaleCache: usedStaleCache)
    }

    private func loadShelf(
        kind: MovieDiscoveryShelfKind,
        request: MovieDiscoveryRequest,
        forceRefresh: Bool
    ) async -> (shelf: MovieDiscoveryShelf, usedStaleCache: Bool) {
        if !forceRefresh,
           let cached = await cachedShelf(kind: kind, request: request) {
            return (cached.shelf, cached.freshness == .stale)
        }

        do {
            let response = try await fetchShelfResponse(kind: kind, request: request)
            await write(response, kind: kind, request: request)
            return (makeShelf(from: response, request: request, freshness: .fresh), false)
        } catch {
            if let cached = await cachedShelf(kind: kind, request: request) {
                return (cached.shelf, cached.freshness == .stale)
            }
            return (
                MovieDiscoveryShelf(
                    kind: kind,
                    subtitle: kind.subtitle(regionCode: request.regionCode, seedTitle: nil),
                    results: [],
                    errorMessage: errorMessage(for: error)
                ),
                false
            )
        }
    }

    private func cachedShelf(
        kind: MovieDiscoveryShelfKind,
        request: MovieDiscoveryRequest
    ) async -> (shelf: MovieDiscoveryShelf, freshness: TMDbMetadataCacheFreshness)? {
        guard let cacheStore else { return nil }
        let key = MovieDiscoveryCacheKey.cacheKey(kind: kind, request: request)
        guard let read = await cacheStore.read(MovieDiscoveryResponse.self, for: key, now: dependencies.now()),
              read.freshness.isUsable else {
            return nil
        }

        let response = read.payload ?? MovieDiscoveryResponse(
            kind: kind,
            results: [],
            seedTitle: nil,
            generatedAt: read.entry.createdAt
        )
        return (makeShelf(from: response, request: request, freshness: read.freshness), read.freshness)
    }

    private func write(
        _ response: MovieDiscoveryResponse,
        kind: MovieDiscoveryShelfKind,
        request: MovieDiscoveryRequest
    ) async {
        await cacheStore?.write(
            response,
            for: MovieDiscoveryCacheKey.cacheKey(kind: kind, request: request),
            policy: response.results.isEmpty ? .negativeRecommendations : .recommendations,
            now: dependencies.now(),
            isNegative: response.results.isEmpty
        )
    }

    private func makeShelf(
        from response: MovieDiscoveryResponse,
        request: MovieDiscoveryRequest,
        freshness: TMDbMetadataCacheFreshness?
    ) -> MovieDiscoveryShelf {
        let filtered = MovieDiscoveryResultFilter.filteredResults(response.results, request: request)
        return MovieDiscoveryShelf(
            kind: response.kind,
            subtitle: response.kind.subtitle(regionCode: request.regionCode, seedTitle: response.seedTitle),
            results: filtered,
            seedTitle: response.seedTitle,
            lastUpdated: response.generatedAt,
            freshness: freshness,
            errorMessage: nil
        )
    }

    private func fetchShelfResponse(
        kind: MovieDiscoveryShelfKind,
        request: MovieDiscoveryRequest
    ) async throws -> MovieDiscoveryResponse {
        let results: [TMDbMovieResult]
        let seedTitle: String?

        switch kind {
        case .personalizedRecommendations:
            let seeds = MovieDiscoverySeedBuilder.seedMovies(from: request.existingWatched).prefix(3)
            seedTitle = seeds.first?.title
            guard !seeds.isEmpty else {
                return MovieDiscoveryResponse(
                    kind: kind,
                    results: [],
                    seedTitle: nil,
                    generatedAt: dependencies.now()
                )
            }

            var aggregated: [TMDbMovieResult] = []
            for seed in seeds {
                guard let tmdbId = seed.tmdbId else { continue }
                let response = try await dependencies.fetchMovieRecommendations(tmdbId, 1)
                aggregated.append(contentsOf: response.results)
                if aggregated.count >= 80 { break }
            }

            if aggregated.isEmpty,
               let firstID = seeds.first?.tmdbId {
                let response = try await dependencies.fetchMovieSimilar(firstID, 1)
                aggregated = response.results
            }
            results = aggregated

        case .preferredProviders:
            seedTitle = nil
            guard !request.preferredProviderIDs.isEmpty else {
                return MovieDiscoveryResponse(
                    kind: kind,
                    results: [],
                    seedTitle: nil,
                    generatedAt: dependencies.now()
                )
            }
            results = try await dependencies.fetchDiscoverMoviesWithWatchProviders(
                request.regionCode,
                request.preferredProviderIDs.sorted(),
                ["flatrate", "free", "ads"],
                1
            ).results

        case .trending:
            seedTitle = nil
            results = try await dependencies.fetchTrendingMovies(.week, 1).results

        case .nowPlaying:
            seedTitle = nil
            results = try await dependencies.fetchNowPlayingMovies(request.regionCode, 1).results

        case .topRated:
            seedTitle = nil
            results = try await dependencies.fetchTopRatedMovies(1).results

        case .popular:
            seedTitle = nil
            results = try await dependencies.fetchPopularMovies(1).results
        }

        return MovieDiscoveryResponse(
            kind: kind,
            results: results,
            seedTitle: seedTitle,
            generatedAt: dependencies.now()
        )
    }

    private func errorMessage(for error: Error) -> String {
        if case TMDbError.missingAPIKey = error {
            return "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
        }
        return "Konnte diese Discovery-Reihe nicht laden."
    }
}
