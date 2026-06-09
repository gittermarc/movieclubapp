import Foundation
import Testing
@testable import filmfreaks

struct MovieDiscoveryProviderPreferencesTests {

    @Test func preferredProviderShelfOnlyFetchesWhenPreferencesExist() async {
        var calls: [(String?, [Int], [String], Int)] = []
        let service = MovieDiscoveryService(
            dependencies: dependencies(
                fetchDiscoverMoviesWithWatchProviders: { region, ids, types, page in
                    calls.append((region, ids, types, page))
                    return response([result(id: 42, title: "Streamable")])
                }
            ),
            cacheStore: nil
        )

        let emptyLoad = await service.loadShelves(
            request: request(preferredProviderIDs: []),
            kinds: [.preferredProviders]
        )
        let preferredLoad = await service.loadShelves(
            request: request(regionCode: "de", preferredProviderIDs: [119, 8]),
            kinds: [.preferredProviders]
        )

        #expect(emptyLoad.shelves.first?.results.isEmpty == true)
        #expect(calls.count == 1)
        #expect(calls.first?.0 == "DE")
        #expect(calls.first?.1 == [8, 119])
        #expect(calls.first?.2 == ["flatrate", "free", "ads"])
        #expect(calls.first?.3 == 1)
        #expect(preferredLoad.shelves.first?.kind == .preferredProviders)
        #expect(preferredLoad.shelves.first?.results.map(\.id) == [42])
    }

    @Test func preferredProviderCacheKeyIncludesRegionAndProviderIDs() {
        let key = MovieDiscoveryCacheKey.cacheKey(
            kind: .preferredProviders,
            request: request(regionCode: "de", preferredProviderIDs: [119, 8])
        )

        #expect(key.namespace == "discovery")
        #expect(key.profileName == MovieDiscoveryShelfKind.preferredProviders.rawValue)
        #expect(key.regionCode == "DE")
        #expect(key.variant?.contains("8-119") == true)
    }

    private func dependencies(
        fetchDiscoverMoviesWithWatchProviders: @escaping (String?, [Int], [String], Int) async throws -> TMDbSearchResponse
    ) -> MovieDiscoveryService.Dependencies {
        MovieDiscoveryService.Dependencies(
            fetchTrendingMovies: { _, _ in response([]) },
            fetchNowPlayingMovies: { _, _ in response([]) },
            fetchTopRatedMovies: { _ in response([]) },
            fetchPopularMovies: { _ in response([]) },
            fetchMovieRecommendations: { _, _ in response([]) },
            fetchMovieSimilar: { _, _ in response([]) },
            fetchDiscoverMoviesWithWatchProviders: fetchDiscoverMoviesWithWatchProviders,
            now: { Date(timeIntervalSince1970: 1_000) }
        )
    }

    private func request(
        regionCode: String? = "DE",
        preferredProviderIDs: Set<Int>
    ) -> MovieDiscoveryRequest {
        MovieDiscoveryRequest(
            existingWatched: [],
            existingBacklog: [],
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: regionCode,
            preferredProviderIDs: preferredProviderIDs
        )
    }

    private func response(_ results: [TMDbMovieResult]) -> TMDbSearchResponse {
        TMDbSearchResponse(page: 1, results: results, total_pages: 1, total_results: results.count)
    }

    private func result(id: Int, title: String) -> TMDbMovieResult {
        TMDbMovieResult(id: id, title: title, release_date: "2024-01-01", vote_average: 7.0, poster_path: nil)
    }
}
