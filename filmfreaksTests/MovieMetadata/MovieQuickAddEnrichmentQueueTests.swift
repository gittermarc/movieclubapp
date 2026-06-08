import Foundation
import Testing
@testable import filmfreaks

struct MovieQuickAddEnrichmentQueueTests {

    @Test func duplicateMovieIdSharesOneRunningLoad() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let movieId = UUID()
        let movie = Movie(id: movieId, title: "Arrival", year: "2016", tmdbId: 42)
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    try await Task.sleep(nanoseconds: 20_000_000)
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders()
                }
            )
        )
        let service = MovieQuickAddEnrichmentService(repository: repository)
        let queue = MovieQuickAddEnrichmentQueue(service: service, maxConcurrentLoads: 2)
        let request = try #require(MovieQuickAddEnrichmentRequest(movie: movie, isBacklog: true))

        async let first = queue.loadPatch(for: request)
        async let second = queue.loadPatch(for: request)

        let firstPatch = await first
        let secondPatch = await second
        let detailCalls = await probe.detailsCount()
        let providerCalls = await probe.providersCount()

        #expect(firstPatch != nil)
        #expect(secondPatch != nil)
        #expect(detailCalls == 1)
        #expect(providerCalls == 0)
    }

    @Test func queueLimitsParallelLoads() async throws {
        let probe = MovieQuickAddConcurrencyProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.enter()
                    try await Task.sleep(nanoseconds: 20_000_000)
                    await probe.leave()
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, _ in
                    MovieMetadataTestFixtures.makeProviders()
                }
            )
        )
        let service = MovieQuickAddEnrichmentService(repository: repository)
        let queue = MovieQuickAddEnrichmentQueue(service: service, maxConcurrentLoads: 2)
        let requests = try (0..<5).map { offset in
            try #require(
                MovieQuickAddEnrichmentRequest(
                    movie: Movie(
                        id: UUID(),
                        title: "Arrival \(offset)",
                        year: "2016",
                        tmdbId: 100 + offset
                    ),
                    isBacklog: offset.isMultiple(of: 2)
                )
            )
        }

        await withTaskGroup(of: MovieMetadataLoadedMoviePatch?.self) { group in
            for request in requests {
                group.addTask {
                    await queue.loadPatch(for: request)
                }
            }

            for await _ in group { }
        }

        let maxRunning = await probe.maxRunningCount()
        let totalCalls = await probe.totalCount()

        #expect(maxRunning <= 2)
        #expect(totalCalls == 5)
    }
}

actor MovieQuickAddConcurrencyProbe {
    private var running = 0
    private var maximumRunning = 0
    private var total = 0

    func enter() {
        running += 1
        total += 1
        maximumRunning = max(maximumRunning, running)
    }

    func leave() {
        running = max(0, running - 1)
    }

    func maxRunningCount() -> Int {
        maximumRunning
    }

    func totalCount() -> Int {
        total
    }
}
