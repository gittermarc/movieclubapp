import Foundation
import Testing
@testable import filmfreaks

struct MovieQuickAddEnrichmentServiceTests {

    @Test func serviceUsesQuickAddProfileWithoutWatchProviders() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders()
                }
            )
        )
        let service = MovieQuickAddEnrichmentService(repository: repository)
        let request = try #require(
            MovieQuickAddEnrichmentRequest(
                movie: Movie(title: "Arrival", year: "2016", tmdbId: 42),
                isBacklog: true
            )
        )

        let patch = await service.loadPatch(for: request)
        let detailsCount = await probe.detailsCount()
        let providersCount = await probe.providersCount()

        #expect(patch != nil)
        #expect(detailsCount == 1)
        #expect(providersCount == 0)
    }

    @Test func serviceSilentlyIgnoresMetadataErrors() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { _ in
                    await probe.recordDetails()
                    throw TMDbError.requestFailed
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders()
                }
            )
        )
        let service = MovieQuickAddEnrichmentService(repository: repository)
        let request = try #require(
            MovieQuickAddEnrichmentRequest(
                movie: Movie(title: "Arrival", year: "2016", tmdbId: 42),
                isBacklog: false
            )
        )

        let patch = await service.loadPatch(for: request)
        let detailsCount = await probe.detailsCount()
        let providersCount = await probe.providersCount()

        #expect(patch == nil)
        #expect(detailsCount == 1)
        #expect(providersCount == 0)
    }

    @Test func alreadyCompleteMovieSkipsRepositoryLoad() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders()
                }
            )
        )
        let service = MovieQuickAddEnrichmentService(repository: repository)
        let request = try #require(
            MovieQuickAddEnrichmentRequest(
                movie: MovieMetadataTestFixtures.makeCompleteMovie(),
                isBacklog: true
            )
        )

        let patch = await service.loadPatch(for: request)
        let detailsCount = await probe.detailsCount()
        let providersCount = await probe.providersCount()

        #expect(patch == nil)
        #expect(detailsCount == 0)
        #expect(providersCount == 0)
    }
}
