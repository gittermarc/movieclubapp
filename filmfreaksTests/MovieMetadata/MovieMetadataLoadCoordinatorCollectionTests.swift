import Testing
@testable import filmfreaks

@MainActor
struct MovieMetadataLoadCoordinatorCollectionTests {

    @Test func collectionIsLoadedWhenDetailsContainCollectionSummary() async throws {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    MovieMetadataTestFixtures.makeDetails(
                        id: id,
                        belongsToCollection: MovieMetadataTestFixtures.makeCollectionSummary(id: 900)
                    )
                },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() },
                fetchCollectionDetails: { id in
                    await probe.recordCollection(id: id)
                    return MovieMetadataTestFixtures.makeCollectionDetails(id: id)
                }
            )
        )
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(repository: repository, ingestPopularityFromCredits: { _ in })
        )

        _ = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )

        let collections = await probe.collections()
        let detailsID = coordinator.details?.id
        let collectionID = coordinator.collectionDetails?.id
        let detailsError = coordinator.detailsError

        #expect(collections == [900])
        #expect(detailsID == 42)
        #expect(collectionID == 900)
        #expect(detailsError == nil)
    }

    @Test func collectionFailureDoesNotBreakDetailsState() async {
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in
                    MovieMetadataTestFixtures.makeDetails(
                        id: id,
                        belongsToCollection: MovieMetadataTestFixtures.makeCollectionSummary(id: 900)
                    )
                },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() },
                fetchCollectionDetails: { _ in throw TMDbError.requestFailed }
            )
        )
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(repository: repository, ingestPopularityFromCredits: { _ in })
        )

        _ = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )

        let detailsID = coordinator.details?.id
        let collectionDetails = coordinator.collectionDetails
        let detailsError = coordinator.detailsError
        let isLoadingDetails = coordinator.isLoadingDetails

        #expect(detailsID == 42)
        #expect(collectionDetails == nil)
        #expect(detailsError == nil)
        #expect(isLoadingDetails == false)
    }
}
