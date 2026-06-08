import Testing
@testable import filmfreaks

@MainActor
struct MovieMetadataLoadCoordinatorRecommendationsTests {

    @Test func recommendationsAreLoadedFromRecommendationEndpoint() async {
        let probe = MovieMetadataRepositoryProbe()
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in MovieMetadataTestFixtures.makeDetails(id: id) },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() },
                fetchMovieRecommendations: { _, _ in
                    await probe.recordRecommendations()
                    return MovieMetadataTestFixtures.makeSearchResponse(
                        results: [
                            MovieMetadataTestFixtures.makeMovieResult(id: 70, title: "Fresh")
                        ]
                    )
                },
                fetchMovieSimilar: { _, _ in
                    await probe.recordSimilar()
                    return MovieMetadataTestFixtures.makeSearchResponse(results: [])
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

        let recommendationCalls = await probe.recommendationsCount()
        let similarCalls = await probe.similarCount()
        let recommendationIDs = coordinator.recommendations.map(\.id)
        let recommendationSource = coordinator.recommendationsSource

        #expect(recommendationIDs == [70])
        #expect(recommendationSource == .recommendations)
        #expect(recommendationCalls == 1)
        #expect(similarCalls == 0)
    }

    @Test func similarIsUsedOnlyWhenRecommendationsAreEmpty() async {
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
                    return MovieMetadataTestFixtures.makeSearchResponse(
                        results: [
                            MovieMetadataTestFixtures.makeMovieResult(id: 71, title: "Similar")
                        ]
                    )
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

        let recommendationCalls = await probe.recommendationsCount()
        let similarCalls = await probe.similarCount()
        let recommendationIDs = coordinator.recommendations.map(\.id)
        let recommendationSource = coordinator.recommendationsSource

        #expect(recommendationIDs == [71])
        #expect(recommendationSource == .similar)
        #expect(recommendationCalls == 1)
        #expect(similarCalls == 1)
    }

    @Test func recommendationFailuresDoNotBreakDetailsState() async {
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in MovieMetadataTestFixtures.makeDetails(id: id) },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() },
                fetchMovieRecommendations: { _, _ in throw TMDbError.requestFailed },
                fetchMovieSimilar: { _, _ in throw TMDbError.requestFailed }
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
        let recommendations = coordinator.recommendations
        let recommendationSource = coordinator.recommendationsSource
        let detailsError = coordinator.detailsError
        let isLoadingDetails = coordinator.isLoadingDetails

        #expect(detailsID == 42)
        #expect(recommendations.isEmpty)
        #expect(recommendationSource == nil)
        #expect(detailsError == nil)
        #expect(isLoadingDetails == false)
    }
}
