import Foundation
import Testing
@testable import filmfreaks

struct MovieMetadataRepositoryTests {

    @Test func detailPageLoadsDetailsAndWatchProviders() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    return MovieMetadataTestFixtures.makeProviders(link: "https://example.com/\(region ?? "none")")
                }
            )
        )

        let response = try await repository.metadata(
            for: 42,
            profile: .detailPage(regionCode: "de")
        )
        let responseDetailsID = response.details.id
        let responseProviderLink = response.watchProvidersCountry?.link

        let detailCalls = await probe.detailsCount()
        let providerCalls = await probe.providersCount()
        let regions = await probe.regions()

        #expect(responseDetailsID == 42)
        #expect(responseProviderLink == "https://example.com/DE")
        #expect(detailCalls == 1)
        #expect(providerCalls == 1)
        #expect(regions == [Optional("DE")])
    }

    @Test func quickAddLoadsDetailsWithoutWatchProviders() async throws {
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

        let response = try await repository.metadata(for: 42, profile: .quickAdd)
        let responseDetailsID = response.details.id
        let hasWatchProviders = response.watchProvidersCountry != nil

        let detailCalls = await probe.detailsCount()
        let providerCalls = await probe.providersCount()

        #expect(responseDetailsID == 42)
        #expect(!hasWatchProviders)
        #expect(detailCalls == 1)
        #expect(providerCalls == 0)
    }

    @Test func parallelIdenticalRequestsAreDeduplicated() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    await probe.recordDetails()
                    try await Task.sleep(nanoseconds: 20_000_000)
                    return MovieMetadataTestFixtures.makeDetails(id: id)
                },
                fetchMovieWatchProviders: { _, region in
                    await probe.recordProvider(region: region)
                    try await Task.sleep(nanoseconds: 20_000_000)
                    return MovieMetadataTestFixtures.makeProviders()
                }
            )
        )

        async let first = repository.metadata(for: 42, profile: .detailPage(regionCode: "DE"))
        async let second = repository.metadata(for: 42, profile: .detailPage(regionCode: "DE"))

        let firstResponse = try await first
        let secondResponse = try await second
        let firstDetailsID = firstResponse.details.id
        let secondDetailsID = secondResponse.details.id

        let detailCalls = await probe.detailsCount()
        let providerCalls = await probe.providersCount()

        #expect(firstDetailsID == secondDetailsID)
        #expect(detailCalls == 1)
        #expect(providerCalls == 1)
    }
}
