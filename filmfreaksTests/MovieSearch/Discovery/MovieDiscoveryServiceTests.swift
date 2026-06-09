import Foundation
import Testing
@testable import filmfreaks

struct MovieDiscoveryServiceTests {

    @Test func trendingShelfUsesTrendingEndpoint() async {
        var calls: [String] = []
        let service = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchTrendingMovies: { timeWindow, page in
                    calls.append("trending-\(timeWindow.rawValue)-\(page)")
                    return self.response([self.result(id: 10, title: "Trend")])
                }
            ),
            cacheStore: nil
        )

        let load = await service.loadShelves(request: request(), kinds: [.trending])
        let resultIDs = load.shelves.first?.results.map(\.id)

        #expect(calls == ["trending-week-1"])
        #expect(resultIDs == [10])
    }

    @Test func nowPlayingUsesNormalizedRegion() async {
        var regions: [String?] = []
        let service = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchNowPlayingMovies: { region, _ in
                    regions.append(region)
                    return self.response([self.result(id: 11, title: "Cinema")])
                }
            ),
            cacheStore: nil
        )

        let load = await service.loadShelves(request: request(regionCode: "de"), kinds: [.nowPlaying])
        let resultIDs = load.shelves.first?.results.map(\.id)

        #expect(regions == ["DE"])
        #expect(resultIDs == [11])
    }

    @Test func topRatedAndPopularUseSeparateShelves() async {
        let service = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchTopRatedMovies: { _ in self.response([self.result(id: 20, title: "Top")]) },
                fetchPopularMovies: { _ in self.response([self.result(id: 30, title: "Popular")]) }
            ),
            cacheStore: nil
        )

        let load = await service.loadShelves(request: request(), kinds: [.topRated, .popular])
        let idsByKind = Dictionary(uniqueKeysWithValues: load.shelves.map { ($0.kind, $0.results.map(\.id)) })

        #expect(idsByKind[.topRated] == [20])
        #expect(idsByKind[.popular] == [30])
    }

    @Test func personalizedRecommendationsUseWatchedSeedsAndSimilarFallback() async {
        var recommendationCalls: [Int] = []
        var similarCalls: [Int] = []
        let watched = [movie(title: "Seed", year: "2020", tmdbId: 42, watchedDate: Date())]
        let service = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchMovieRecommendations: { id, _ in
                    recommendationCalls.append(id)
                    return self.response([])
                },
                fetchMovieSimilar: { id, _ in
                    similarCalls.append(id)
                    return self.response([self.result(id: 77, title: "Similar")])
                }
            ),
            cacheStore: nil
        )

        let load = await service.loadShelves(
            request: request(existingWatched: watched),
            kinds: [.personalizedRecommendations]
        )
        let shelf = load.shelves.first

        #expect(recommendationCalls == [42])
        #expect(similarCalls == [42])
        #expect(shelf?.seedTitle == "Seed")
        #expect(shelf?.results.map(\.id) == [77])
    }

    @Test func cacheHitPreventsNetworkRequest() async {
        let directory = temporaryDirectory()
        let cache = TMDbMetadataCacheFileStore(baseDirectory: directory)
        var firstCalls = 0
        let firstService = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchTrendingMovies: { _, _ in
                    firstCalls += 1
                    return self.response([self.result(id: 10, title: "Cached Trend")])
                }
            ),
            cacheStore: cache
        )
        let firstLoad = await firstService.loadShelves(request: request(), kinds: [.trending])
        let firstIDs = firstLoad.shelves.first?.results.map(\.id)

        var secondCalls = 0
        let secondService = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchTrendingMovies: { _, _ in
                    secondCalls += 1
                    return self.response([self.result(id: 99, title: "Should Not Load")])
                }
            ),
            cacheStore: cache
        )
        let secondLoad = await secondService.loadShelves(request: request(), kinds: [.trending])
        let secondIDs = secondLoad.shelves.first?.results.map(\.id)

        #expect(firstCalls == 1)
        #expect(firstIDs == [10])
        #expect(secondCalls == 0)
        #expect(secondIDs == [10])
    }

    @Test func staleCacheIsReturnedWithoutBlockingOnNetwork() async {
        let directory = temporaryDirectory()
        let cache = TMDbMetadataCacheFileStore(baseDirectory: directory)
        let request = request()
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let staleDate = oldDate.addingTimeInterval(2 * 24 * 60 * 60)
        let cached = MovieDiscoveryResponse(
            kind: .trending,
            results: [result(id: 44, title: "Stale Trend")],
            seedTitle: nil,
            generatedAt: oldDate
        )
        await cache.write(
            cached,
            for: MovieDiscoveryCacheKey.cacheKey(kind: .trending, request: request),
            policy: .recommendations,
            now: oldDate,
            isNegative: false
        )

        var networkCalls = 0
        let service = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchTrendingMovies: { _, _ in
                    networkCalls += 1
                    return self.response([self.result(id: 99, title: "Network")])
                },
                now: { staleDate }
            ),
            cacheStore: cache
        )

        let load = await service.loadShelves(request: request, kinds: [.trending])
        let resultIDs = load.shelves.first?.results.map(\.id)

        #expect(networkCalls == 0)
        #expect(load.usedStaleCache)
        #expect(resultIDs == [44])
    }

    @Test func shelfErrorDoesNotDestroyOtherShelves() async {
        let service = MovieDiscoveryService(
            dependencies: makeDependencies(
                fetchTrendingMovies: { _, _ in throw TestError.failed },
                fetchPopularMovies: { _ in self.response([self.result(id: 30, title: "Popular")]) }
            ),
            cacheStore: nil
        )

        let load = await service.loadShelves(request: request(), kinds: [.trending, .popular])
        let trending = load.shelves.first { $0.kind == .trending }
        let popular = load.shelves.first { $0.kind == .popular }

        #expect(trending?.results.isEmpty == true)
        #expect(trending?.errorMessage != nil)
        #expect(popular?.results.map(\.id) == [30])
    }

    private func makeDependencies(
        fetchTrendingMovies: ((TMDbTrendingTimeWindow, Int) async throws -> TMDbSearchResponse)? = nil,
        fetchNowPlayingMovies: ((String?, Int) async throws -> TMDbSearchResponse)? = nil,
        fetchTopRatedMovies: ((Int) async throws -> TMDbSearchResponse)? = nil,
        fetchPopularMovies: ((Int) async throws -> TMDbSearchResponse)? = nil,
        fetchMovieRecommendations: ((Int, Int) async throws -> TMDbSearchResponse)? = nil,
        fetchMovieSimilar: ((Int, Int) async throws -> TMDbSearchResponse)? = nil,
        now: (() -> Date)? = nil
    ) -> MovieDiscoveryService.Dependencies {
        MovieDiscoveryService.Dependencies(
            fetchTrendingMovies: fetchTrendingMovies ?? { _, _ in self.response([]) },
            fetchNowPlayingMovies: fetchNowPlayingMovies ?? { _, _ in self.response([]) },
            fetchTopRatedMovies: fetchTopRatedMovies ?? { _ in self.response([]) },
            fetchPopularMovies: fetchPopularMovies ?? { _ in self.response([]) },
            fetchMovieRecommendations: fetchMovieRecommendations ?? { _, _ in self.response([]) },
            fetchMovieSimilar: fetchMovieSimilar ?? { _, _ in self.response([]) },
            now: now ?? { Date(timeIntervalSince1970: 1_000) }
        )
    }

    private func request(
        existingWatched: [Movie] = [],
        existingBacklog: [Movie] = [],
        regionCode: String? = "DE"
    ) -> MovieDiscoveryRequest {
        MovieDiscoveryRequest(
            existingWatched: existingWatched,
            existingBacklog: existingBacklog,
            localWatchedKeys: Set(existingWatched.map { MovieSearchMapper.key(for: $0) }),
            localBacklogKeys: Set(existingBacklog.map { MovieSearchMapper.key(for: $0) }),
            regionCode: regionCode
        )
    }

    private func response(_ results: [TMDbMovieResult]) -> TMDbSearchResponse {
        TMDbSearchResponse(page: 1, results: results, total_pages: 1, total_results: results.count)
    }

    private func result(id: Int, title: String, releaseDate: String = "2024-01-01") -> TMDbMovieResult {
        TMDbMovieResult(
            id: id,
            title: title,
            release_date: releaseDate,
            vote_average: 7.0,
            poster_path: nil
        )
    }

    private func movie(title: String, year: String, tmdbId: Int?, watchedDate: Date? = nil) -> Movie {
        Movie(
            title: title,
            year: year,
            watchedDate: watchedDate,
            tmdbId: tmdbId
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tmdb-discovery-tests-\(UUID().uuidString)", isDirectory: true)
    }

    enum TestError: Error {
        case failed
    }
}
