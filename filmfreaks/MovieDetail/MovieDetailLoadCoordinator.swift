//
//  MovieDetailLoadCoordinator.swift
//  filmfreaks
//
//  Created by Marc Fechner on 09.04.26.
//

import Foundation
import Combine

struct MovieDetailLoadedMoviePatch {
    let genres: [String]?
    let genreIds: [Int]?
    let keywords: [String]?
    let keywordIds: [Int]?
    let cast: [CastMember]?
    let directors: [CastMember]?
    let tmdbRating: Double
    let posterPath: String?

    init(details: TMDbMovieDetails) {
        let normalizedGenres = details.genres?
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedKeywords = details.keywords?.allKeywords
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedCast = details.credits?.cast
            .prefix(30)
            .map {
                CastMember(
                    personId: $0.id,
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.name.isEmpty }
        let normalizedDirectors = details.credits?.crew
            .filter { ($0.job ?? "").lowercased() == "director" }
            .map {
                CastMember(
                    personId: $0.id,
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.name.isEmpty }
        let mappedGenreIds = details.genres?.map(\.id)
        let mappedKeywordIds = details.keywords?.allKeywords.map(\.id)

        genres = normalizedGenres?.isEmpty == false ? normalizedGenres : nil
        genreIds = mappedGenreIds?.isEmpty == false ? mappedGenreIds : nil
        keywords = normalizedKeywords?.isEmpty == false ? normalizedKeywords : nil
        keywordIds = mappedKeywordIds?.isEmpty == false ? mappedKeywordIds : nil
        cast = normalizedCast?.isEmpty == false ? normalizedCast : nil
        directors = normalizedDirectors?.isEmpty == false ? normalizedDirectors : nil
        tmdbRating = details.vote_average
        posterPath = details.poster_path
    }

    func apply(to movie: inout Movie) {
        if let genres, !genres.isEmpty {
            movie.genres = genres
        }

        if let genreIds, !genreIds.isEmpty {
            movie.genreIds = genreIds
        }

        if let keywords, !keywords.isEmpty {
            movie.keywords = keywords
        }

        if let keywordIds, !keywordIds.isEmpty {
            movie.keywordIds = keywordIds
        }

        if let cast, !cast.isEmpty {
            movie.cast = cast
        }

        if let directors, !directors.isEmpty {
            movie.directors = directors
        }

        movie.tmdbRating = tmdbRating
        if let posterPath {
            movie.posterPath = posterPath
        }
    }
}

@MainActor
final class MovieDetailLoadCoordinator: ObservableObject {
    struct Dependencies {
        var fetchMovieDetails: (Int) async throws -> TMDbMovieDetails
        var fetchMovieWatchProviders: (Int, String?) async throws -> TMDbWatchProvidersCountry?
        var ingestPopularityFromCredits: (TMDbCredits) -> Void

        static var live: Dependencies {
            Dependencies(
                fetchMovieDetails: { id in
                    try await TMDbAPI.shared.fetchMovieDetails(id: id)
                },
                fetchMovieWatchProviders: { id, region in
                    try await TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)
                },
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

    private let dependencies: Dependencies
    private(set) var lastLoadedMovieID: Int?
    private(set) var lastLoadedWatchProvidersRegionCode: String?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    convenience init() {
        self.init(dependencies: .live)
    }

    func loadDetails(for movie: Movie, effectiveRegionCode: String) async -> MovieDetailLoadedMoviePatch? {
        guard let movieId = movie.tmdbId else { return nil }

        beginFullLoad()

        do {
            async let detailsTask = dependencies.fetchMovieDetails(movieId)
            async let providersTask = dependencies.fetchMovieWatchProviders(movieId, effectiveRegionCode)

            let fetchedDetails = try await detailsTask
            let fetchedProviders = try? await providersTask

            if let credits = fetchedDetails.credits {
                dependencies.ingestPopularityFromCredits(credits)
            }

            applyFullLoadSuccess(
                details: fetchedDetails,
                providersCountry: fetchedProviders,
                movieId: movieId,
                effectiveRegionCode: effectiveRegionCode
            )
            return MovieDetailLoadedMoviePatch(details: fetchedDetails)
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

        do {
            let providersCountry = try await dependencies.fetchMovieWatchProviders(movieId, effectiveRegionCode)
            applyWatchProvidersSuccess(
                providersCountry: providersCountry,
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

    private func applyFullLoadSuccess(
        details: TMDbMovieDetails,
        providersCountry: TMDbWatchProvidersCountry?,
        movieId: Int,
        effectiveRegionCode: String
    ) {
        self.details = details
        applyWatchProvidersSuccess(
            providersCountry: providersCountry,
            movieId: movieId,
            effectiveRegionCode: effectiveRegionCode
        )
        isLoadingDetails = false
    }

    private func applyFullLoadFailure(errorMessage: String) {
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
}
