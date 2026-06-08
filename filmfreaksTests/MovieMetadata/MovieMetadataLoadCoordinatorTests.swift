import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieMetadataLoadCoordinatorTests {

    @Test func fullLoadPublishesDetailsProvidersAndMoviePatch() async throws {
        var ingestedCreditsCount = 0
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(
                repository: makeRepository(),
                ingestPopularityFromCredits: { _ in ingestedCreditsCount += 1 }
            )
        )
        var movie = Movie(title: "Arrival", year: "2016", tmdbId: 42)

        let patch = await coordinator.loadDetails(for: movie, effectiveRegionCode: "DE")
        let appliedPatch = try #require(patch)
        appliedPatch.apply(to: &movie)

        #expect(coordinator.details?.id == 42)
        #expect(coordinator.isLoadingDetails == false)
        #expect(coordinator.detailsError == nil)
        #expect(coordinator.isLoadingWatchProviders == false)
        #expect(coordinator.didLoadWatchProviders == true)
        #expect(coordinator.watchProvidersLink?.absoluteString == "https://example.com/DE")
        #expect(ingestedCreditsCount == 1)

        #expect(movie.tmdbRating == 8.4)
        #expect(movie.posterPath == "/poster.jpg")
        #expect(movie.genres == ["Science Fiction", "Drama"])
        #expect(movie.genreIds == [1, 2])
        #expect(movie.keywords == ["First Contact", "Arrival"])
        #expect(movie.keywordIds == [10, 11])
        #expect(movie.cast?.map(\.name) == ["Amy Adams", "Jeremy Renner"])
        #expect(movie.directors?.map(\.name) == ["Denis Villeneuve"])
    }

    @Test func watchProvidersReloadUpdatesRegionSpecificStateAndKeepsDetails() async {
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
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(
                repository: repository,
                ingestPopularityFromCredits: { _ in }
            )
        )

        _ = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )
        await coordinator.reloadWatchProvidersIfNeeded(for: 42, effectiveRegionCode: "US")

        let regions = await probe.regions()

        #expect(regions == [Optional("DE"), Optional("US")])
        #expect(coordinator.details?.id == 42)
        #expect(coordinator.watchProvidersLink?.absoluteString == "https://example.com/US")
        #expect(coordinator.didLoadWatchProviders == true)
        #expect(coordinator.isLoadingWatchProviders == false)
    }

    @Test func watchProvidersReloadDecisionUsesMovieAndRegionState() async {
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(
                repository: makeRepository(),
                ingestPopularityFromCredits: { _ in }
            )
        )

        #expect(coordinator.shouldReloadWatchProviders(movieId: nil, effectiveRegionCode: "DE") == false)
        #expect(coordinator.shouldReloadWatchProviders(movieId: 42, effectiveRegionCode: "DE") == true)

        _ = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )

        #expect(coordinator.shouldReloadWatchProviders(movieId: 42, effectiveRegionCode: "DE") == false)
        #expect(coordinator.shouldReloadWatchProviders(movieId: 42, effectiveRegionCode: "US") == true)
        #expect(coordinator.shouldReloadWatchProviders(movieId: 99, effectiveRegionCode: "DE") == true)
    }

    @Test func missingAPIKeySetsErrorAndCompletesLoadingState() async {
        let repository = TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { _ in throw TMDbError.missingAPIKey },
                fetchMovieWatchProviders: { _, _ in MovieMetadataTestFixtures.makeProviders() }
            )
        )
        let coordinator = MovieMetadataLoadCoordinator(
            dependencies: .init(
                repository: repository,
                ingestPopularityFromCredits: { _ in }
            )
        )

        let patch = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )

        #expect(patch == nil)
        #expect(coordinator.details == nil)
        #expect(coordinator.detailsError == "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen.")
        #expect(coordinator.isLoadingDetails == false)
        #expect(coordinator.isLoadingWatchProviders == false)
        #expect(coordinator.didLoadWatchProviders == true)
    }

    private func makeRepository() -> TMDbMetadataRepository {
        TMDbMetadataRepository(
            dependencies: .init(
                fetchMovieDetails: { id in MovieMetadataTestFixtures.makeDetails(id: id) },
                fetchMovieWatchProviders: { _, region in
                    MovieMetadataTestFixtures.makeProviders(link: "https://example.com/\(region ?? "none")")
                }
            )
        )
    }
}
