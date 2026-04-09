import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieDetailLoadCoordinatorTests {

    @Test func fullLoadPublishesDetailsProvidersAndMoviePatch() async throws {
        var ingestedCreditsCount = 0
        let coordinator = MovieDetailLoadCoordinator(
            dependencies: .init(
                fetchMovieDetails: { _ in self.makeDetails() },
                fetchMovieWatchProviders: { _, _ in self.makeProviders(link: "https://example.com/de") },
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
        #expect(coordinator.watchProvidersLink?.absoluteString == "https://example.com/de")
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
        var requestedRegions: [String?] = []
        let coordinator = MovieDetailLoadCoordinator(
            dependencies: .init(
                fetchMovieDetails: { _ in self.makeDetails() },
                fetchMovieWatchProviders: { _, region in
                    requestedRegions.append(region)
                    if region == "DE" {
                        return self.makeProviders(link: "https://example.com/de")
                    }
                    return self.makeProviders(link: "https://example.com/us")
                },
                ingestPopularityFromCredits: { _ in }
            )
        )

        _ = await coordinator.loadDetails(
            for: Movie(title: "Arrival", year: "2016", tmdbId: 42),
            effectiveRegionCode: "DE"
        )
        await coordinator.reloadWatchProvidersIfNeeded(for: 42, effectiveRegionCode: "US")

        #expect(requestedRegions == ["DE", "US"])
        #expect(coordinator.details?.id == 42)
        #expect(coordinator.watchProvidersLink?.absoluteString == "https://example.com/us")
        #expect(coordinator.didLoadWatchProviders == true)
        #expect(coordinator.isLoadingWatchProviders == false)
    }

    @Test func watchProvidersReloadDecisionUsesMovieAndRegionState() async {
        let coordinator = MovieDetailLoadCoordinator(
            dependencies: .init(
                fetchMovieDetails: { _ in self.makeDetails() },
                fetchMovieWatchProviders: { _, _ in self.makeProviders(link: "https://example.com/de") },
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
        let coordinator = MovieDetailLoadCoordinator(
            dependencies: .init(
                fetchMovieDetails: { _ in throw TMDbError.missingAPIKey },
                fetchMovieWatchProviders: { _, _ in self.makeProviders(link: "https://example.com/de") },
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

    private func makeDetails() -> TMDbMovieDetails {
        TMDbMovieDetails(
            id: 42,
            title: "Arrival",
            tagline: "Why are they here?",
            overview: "Aliens arrive.",
            release_date: "2016-11-10",
            original_title: "Arrival",
            original_language: "en",
            runtime: 116,
            vote_average: 8.4,
            poster_path: "/poster.jpg",
            credits: TMDbCredits(
                cast: [
                    TMDbCast(id: 100, name: "Amy Adams", popularity: 12.0, character: "Louise", profile_path: nil),
                    TMDbCast(id: 101, name: "Jeremy Renner", popularity: 11.0, character: "Ian", profile_path: nil)
                ],
                crew: [
                    TMDbCrew(id: 200, name: "Denis Villeneuve", popularity: 10.0, job: "Director")
                ]
            ),
            keywords: TMDbKeywordsResponse(
                keywords: [
                    TMDbKeyword(id: 10, name: "First Contact"),
                    TMDbKeyword(id: 11, name: "Arrival")
                ],
                results: nil
            ),
            videos: TMDbVideosResponse(results: []),
            genres: [
                TMDbGenre(id: 1, name: "Science Fiction"),
                TMDbGenre(id: 2, name: "Drama")
            ]
        )
    }

    private func makeProviders(link: String) -> TMDbWatchProvidersCountry {
        TMDbWatchProvidersCountry(
            link: link,
            flatrate: [
                TMDbWatchProvider(
                    provider_id: 1,
                    provider_name: "StreamNow",
                    logo_path: nil,
                    display_priority: 1
                )
            ],
            ads: nil,
            free: nil,
            rent: nil,
            buy: nil
        )
    }
}
