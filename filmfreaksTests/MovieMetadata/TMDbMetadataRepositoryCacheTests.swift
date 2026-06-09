import Foundation
import Testing
@testable import filmfreaks

struct TMDbMetadataRepositoryCacheTests {

    @Test func freshDetailPageCachePreventsNetworkRequest() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let now = Date()
        let providers = MovieMetadataTestFixtures.makeProviders(link: "https://example.com/cached")
        let recommendationsPayload = MovieMetadataRecommendationsCachePayload(
            results: [MovieMetadataTestFixtures.makeMovieResult(id: 70)],
            source: .recommendations
        )

        await store.write(
            MovieMetadataTestFixtures.makeDetails(id: 42),
            for: .movieDetails(movieID: 42),
            policy: .movieDetails,
            now: now,
            isNegative: false
        )
        await store.write(
            providers,
            for: .watchProviders(movieID: 42, regionCode: "DE"),
            policy: .watchProviders,
            now: now,
            isNegative: false
        )
        await store.write(
            recommendationsPayload,
            for: .recommendations(movieID: 42),
            policy: .recommendations,
            now: now,
            isNegative: false
        )

        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    return MovieMetadataTestFixtures.makeDetails(id: id, title: "Network")
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders()
                }
            ),
            cacheStore: store
        )

        let result = try await repository.metadataResult(for: 42, profile: .detailPage(regionCode: "de"))
        let detailCalls = await probe.detailsCount()
        let providerCalls = await probe.providersCount()

        #expect(result.freshness == .fresh)
        #expect(result.response.details.title == "Arrival")
        #expect(result.response.watchProvidersCountry?.link == "https://example.com/cached")
        #expect(result.response.recommendations.map(\.id) == [70])
        #expect(detailCalls == 0)
        #expect(providerCalls == 0)
    }

    @MainActor
    @Test func staleCacheIsReturnedAndCoordinatorRevalidatesInBackground() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let staleNow = Date().addingTimeInterval(-31 * 24 * 60 * 60)
        let readNow = Date()

        await store.write(
            MovieMetadataTestFixtures.makeDetails(id: 42, title: "Cached Arrival"),
            for: .movieDetails(movieID: 42),
            policy: .movieDetails,
            now: staleNow,
            isNegative: false
        )
        await store.write(
            MovieMetadataTestFixtures.makeProviders(link: "https://example.com/cached"),
            for: .watchProviders(movieID: 42, regionCode: "DE"),
            policy: .movieDetails,
            now: staleNow,
            isNegative: false
        )
        await store.write(
            MovieMetadataRecommendationsCachePayload(results: [], source: nil),
            for: .recommendations(movieID: 42),
            policy: .movieDetails,
            now: staleNow,
            isNegative: true
        )

        let cached = await store.read(TMDbMovieDetails.self, for: .movieDetails(movieID: 42), now: readNow)
        #expect(cached?.freshness == .stale)

        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    try await Task.sleep(nanoseconds: 40_000_000)
                    return MovieMetadataTestFixtures.makeDetails(id: id, title: "Fresh Arrival")
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders(link: "https://example.com/fresh")
                },
                fetchMovieRecommendations: { _, _ in
                    MovieMetadataTestFixtures.makeSearchResponse(results: [])
                },
                fetchMovieSimilar: { _, _ in
                    MovieMetadataTestFixtures.makeSearchResponse(results: [])
                }
            ),
            cacheStore: store
        )
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(repository: repository, ingestPopularityFromCredits: { _ in })
        )

        let patch = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )
        let cachedTitle = coordinator.details?.title
        let cachedLink = coordinator.watchProvidersLink?.absoluteString
        try await Task.sleep(nanoseconds: 140_000_000)
        let refreshedTitle = coordinator.details?.title
        let refreshedLink = coordinator.watchProvidersLink?.absoluteString
        let detailCalls = await probe.detailsCount()

        #expect(patch != nil)
        #expect(cachedTitle == "Cached Arrival")
        #expect(cachedLink == "https://example.com/cached")
        #expect(refreshedTitle == "Fresh Arrival")
        #expect(refreshedLink == "https://example.com/fresh")
        #expect(detailCalls == 1)
    }

    @Test func nilWatchProvidersAreCachedAsNegativeShortCache() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in MovieMetadataTestFixtures.makeDetails(id: id) },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return nil
                }
            ),
            cacheStore: store
        )

        let first = try await repository.watchProviders(for: 42, regionCode: "de")
        let second = try await repository.watchProviders(for: 42, regionCode: "DE")
        let providerCalls = await probe.providersCount()
        let cached = await store.read(
            TMDbWatchProvidersCountry.self,
            for: .watchProviders(movieID: 42, regionCode: "DE"),
            now: Date()
        )

        #expect(first == nil)
        #expect(second == nil)
        #expect(providerCalls == 1)
        #expect(cached?.entry.isNegative == true)
    }

    @Test func emptyRecommendationsAreCachedAsNegativeShortCache() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in MovieMetadataTestFixtures.makeDetails(id: id) },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() },
                fetchMovieRecommendations: { _, _ in
                    await probe.recordRecommendations()
                    return MovieMetadataTestFixtures.makeSearchResponse(results: [])
                },
                fetchMovieSimilar: { _, _ in
                    await probe.recordSimilar()
                    return MovieMetadataTestFixtures.makeSearchResponse(results: [])
                }
            ),
            cacheStore: store
        )

        let first = try await repository.refreshMetadata(for: 42, profile: .detailPage(regionCode: "DE"))
        let second = try await repository.metadataResult(for: 42, profile: .detailPage(regionCode: "DE"))
        let recommendationCalls = await probe.recommendationsCount()
        let similarCalls = await probe.similarCount()
        let cached = await store.read(
            MovieMetadataRecommendationsCachePayload.self,
            for: .recommendations(movieID: 42),
            now: Date()
        )

        #expect(first.response.recommendations.isEmpty)
        #expect(second.response.recommendations.isEmpty)
        #expect(recommendationCalls == 1)
        #expect(similarCalls == 1)
        #expect(cached?.entry.isNegative == true)
    }

    @Test func missingAPIKeyIsNotCached() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let failing = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { _ in throw TMDbError.missingAPIKey },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() }
            ),
            cacheStore: store
        )

        do {
            _ = try await failing.metadata(for: 42, profile: .quickAdd)
            Issue.record("Expected missing API key to throw")
        } catch TMDbError.missingAPIKey {
        } catch {
            Issue.record("Expected missing API key, got \(error)")
        }

        let cached = await store.read(TMDbMovieDetails.self, for: .movieDetails(movieID: 42), now: Date())
        #expect(cached == nil)
    }

    @Test func inFlightDedupeStillWorksWhenCacheIsEmpty() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    try await Task.sleep(nanoseconds: 20_000_000)
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() }
            ),
            cacheStore: store
        )

        async let first = repository.metadata(for: 42, profile: .quickAdd)
        async let second = repository.metadata(for: 42, profile: .quickAdd)
        _ = try await (first, second)
        let detailCalls = await probe.detailsCount()

        #expect(detailCalls == 1)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tmdb-repository-cache-tests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
