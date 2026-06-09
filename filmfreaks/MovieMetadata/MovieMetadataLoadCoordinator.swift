//
//  MovieMetadataLoadCoordinator.swift
//  filmfreaks
//

import Combine
import Foundation

@MainActor
final class MovieMetadataLoadCoordinator: ObservableObject {
    struct Dependencies {
        var repository: TMDbMetadataRepository
        var ingestPopularityFromCredits: @MainActor (TMDbCredits) -> Void

        static var live: Dependencies {
            Dependencies(
                repository: TMDbMetadataRepository(cacheStore: TMDbMetadataCacheFileStore()),
                ingestPopularityFromCredits: { credits in
                    PersonPopularityStore.shared.ingestPopularity(
                        fromCredits: credits.cast,
                        crew: credits.crew
                    )
                }
            )
        }
    }

    @Published private(set) var details: TMDbMovieDetails?
    @Published private(set) var isLoadingDetails = false
    @Published private(set) var detailsError: String?

    @Published private(set) var watchProvidersCountry: TMDbWatchProvidersCountry?
    @Published private(set) var watchProvidersLink: URL?
    @Published private(set) var isLoadingWatchProviders = false
    @Published private(set) var didLoadWatchProviders = false

    @Published private(set) var collectionDetails: TMDbCollectionDetails?
    @Published private(set) var recommendations: [TMDbMovieResult] = []
    @Published private(set) var recommendationsSource: MovieMetadataRecommendationSource?

    private let dependencies: Dependencies
    private(set) var lastLoadedMovieID: Int?
    private(set) var lastLoadedWatchProvidersRegionCode: String?

    init(dependencies: Dependencies? = nil) {
        self.dependencies = dependencies ?? .live
    }

    func loadDetails(for movie: Movie, effectiveRegionCode: String) async -> MovieMetadataLoadedMoviePatch? {
        await loadDetails(movieID: movie.tmdbId, effectiveRegionCode: effectiveRegionCode)
    }

    func loadDetails(for result: TMDbMovieResult, effectiveRegionCode: String) async -> MovieMetadataLoadedMoviePatch? {
        await loadDetails(movieID: result.id, effectiveRegionCode: effectiveRegionCode)
    }

    func loadDetails(movieID: Int?, effectiveRegionCode: String) async -> MovieMetadataLoadedMoviePatch? {
        guard let movieID else { return nil }

        beginFullLoad()

        let profile = MovieMetadataRequestProfile.detailPage(regionCode: effectiveRegionCode)
        if let cached = await dependencies.repository.cachedMetadata(for: movieID, profile: profile), cached.freshness.isUsable {
            applyRepositoryResult(
                cached,
                movieId: movieID,
                effectiveRegionCode: effectiveRegionCode
            )

            if cached.freshness.shouldRevalidate {
                scheduleMetadataRefresh(movieID: movieID, effectiveRegionCode: effectiveRegionCode)
            }

            return MovieMetadataLoadedMoviePatch(details: cached.response.details)
        }

        do {
            let result = try await dependencies.repository.refreshMetadata(for: movieID, profile: profile)
            applyRepositoryResult(
                result,
                movieId: movieID,
                effectiveRegionCode: effectiveRegionCode
            )
            return MovieMetadataLoadedMoviePatch(details: result.response.details)
        } catch TMDbError.missingAPIKey {
            applyFullLoadFailure(
                errorMessage: "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
            )
            return nil
        } catch {
            applyFullLoadFailure(errorMessage: "Fehler beim Laden der Filmdetails.")
            return nil
        }
    }

    func reloadWatchProvidersIfNeeded(for movieId: Int?, effectiveRegionCode: String) async {
        guard shouldReloadWatchProviders(movieId: movieId, effectiveRegionCode: effectiveRegionCode),
              let movieId else {
            return
        }

        beginWatchProvidersReload()

        if let cached = await dependencies.repository.cachedWatchProviders(
            for: movieId,
            regionCode: effectiveRegionCode
        ), cached.freshness.isUsable {
            applyWatchProvidersSuccess(
                providersCountry: cached.value,
                movieId: movieId,
                effectiveRegionCode: effectiveRegionCode
            )
            if cached.freshness.shouldRevalidate {
                scheduleWatchProvidersRefresh(movieID: movieId, effectiveRegionCode: effectiveRegionCode)
            }
            return
        }

        do {
            let providers = try await dependencies.repository.refreshWatchProviders(
                for: movieId,
                regionCode: effectiveRegionCode
            )
            applyWatchProvidersSuccess(
                providersCountry: providers.value,
                movieId: movieId,
                effectiveRegionCode: effectiveRegionCode
            )
        } catch {
            applyWatchProvidersFailure()
        }
    }

    func shouldReloadWatchProviders(movieId: Int?, effectiveRegionCode: String) -> Bool {
        guard let movieId else { return false }
        if isLoadingWatchProviders { return false }
        if !didLoadWatchProviders { return true }
        if lastLoadedMovieID != movieId { return true }
        return lastLoadedWatchProvidersRegionCode != effectiveRegionCode
    }

    private func beginFullLoad() {
        details = nil
        collectionDetails = nil
        recommendations = []
        recommendationsSource = nil
        isLoadingDetails = true
        detailsError = nil
        beginWatchProvidersReload()
    }

    private func beginWatchProvidersReload() {
        isLoadingWatchProviders = true
        didLoadWatchProviders = false
        watchProvidersCountry = nil
        watchProvidersLink = nil
    }

    private func applyRepositoryResult(
        _ result: MovieMetadataRepositoryResult,
        movieId: Int,
        effectiveRegionCode: String
    ) {
        if let credits = result.response.details.credits {
            dependencies.ingestPopularityFromCredits(credits)
        }

        applyFullLoadSuccess(
            details: result.response.details,
            providersCountry: result.response.watchProvidersCountry,
            collectionDetails: result.response.collectionDetails,
            recommendations: result.response.recommendations,
            recommendationsSource: result.response.recommendationsSource,
            movieId: movieId,
            effectiveRegionCode: effectiveRegionCode
        )
    }

    private func applyFullLoadSuccess(
        details: TMDbMovieDetails,
        providersCountry: TMDbWatchProvidersCountry?,
        collectionDetails: TMDbCollectionDetails?,
        recommendations: [TMDbMovieResult],
        recommendationsSource: MovieMetadataRecommendationSource?,
        movieId: Int,
        effectiveRegionCode: String
    ) {
        self.details = details
        self.collectionDetails = collectionDetails
        self.recommendations = recommendations
        self.recommendationsSource = recommendationsSource
        detailsError = nil
        applyWatchProvidersSuccess(
            providersCountry: providersCountry,
            movieId: movieId,
            effectiveRegionCode: effectiveRegionCode
        )
        isLoadingDetails = false
    }

    private func applyFullLoadFailure(errorMessage: String) {
        collectionDetails = nil
        recommendations = []
        recommendationsSource = nil
        detailsError = errorMessage
        isLoadingDetails = false
        applyWatchProvidersFailure()
    }

    private func applyWatchProvidersSuccess(
        providersCountry: TMDbWatchProvidersCountry?,
        movieId: Int,
        effectiveRegionCode: String
    ) {
        watchProvidersCountry = providersCountry
        if let linkString = providersCountry?.link {
            watchProvidersLink = URL(string: linkString)
        } else {
            watchProvidersLink = nil
        }
        isLoadingWatchProviders = false
        didLoadWatchProviders = true
        lastLoadedMovieID = movieId
        lastLoadedWatchProvidersRegionCode = effectiveRegionCode
    }

    private func applyWatchProvidersFailure() {
        isLoadingWatchProviders = false
        didLoadWatchProviders = true
    }

    private func scheduleMetadataRefresh(movieID: Int, effectiveRegionCode: String) {
        Task { [weak self] in
            await self?.refreshMetadataIfStillCurrent(
                movieID: movieID,
                effectiveRegionCode: effectiveRegionCode
            )
        }
    }

    private func scheduleWatchProvidersRefresh(movieID: Int, effectiveRegionCode: String) {
        Task { [weak self] in
            await self?.refreshWatchProvidersIfStillCurrent(
                movieID: movieID,
                effectiveRegionCode: effectiveRegionCode
            )
        }
    }

    private func refreshMetadataIfStillCurrent(movieID: Int, effectiveRegionCode: String) async {
        do {
            let result = try await dependencies.repository.refreshMetadata(
                for: movieID,
                profile: .detailPage(regionCode: effectiveRegionCode)
            )
            guard lastLoadedMovieID == movieID,
                  lastLoadedWatchProvidersRegionCode == effectiveRegionCode else {
                return
            }
            applyRepositoryResult(
                result,
                movieId: movieID,
                effectiveRegionCode: effectiveRegionCode
            )
        } catch {
            return
        }
    }

    private func refreshWatchProvidersIfStillCurrent(movieID: Int, effectiveRegionCode: String) async {
        do {
            let providers = try await dependencies.repository.refreshWatchProviders(
                for: movieID,
                regionCode: effectiveRegionCode
            )
            guard lastLoadedMovieID == movieID,
                  lastLoadedWatchProvidersRegionCode == effectiveRegionCode else {
                return
            }
            applyWatchProvidersSuccess(
                providersCountry: providers.value,
                movieId: movieID,
                effectiveRegionCode: effectiveRegionCode
            )
        } catch {
            return
        }
    }
}
