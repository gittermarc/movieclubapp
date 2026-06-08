//
//  MovieDetailView+Derived.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

extension MovieDetailView {

    // MARK: - Metadaten aus TMDb

    var director: String? {
        loadCoordinator.details?.credits?.crew.first(where: { ($0.job ?? "").lowercased() == "director" })?.name
    }

    var castList: [TMDbCast] {
        Array(loadCoordinator.details?.credits?.cast.prefix(12) ?? [])
    }

    var keywordNames: [String] {
        MovieMetadataTagPresentation.normalizedNames(
            from: loadCoordinator.details?.keywords?.allKeywords.map(\.name) ?? []
        )
    }

    var genreNames: [String] {
        loadCoordinator.details?.genres?
            .map { $0.name }
            .filter { !$0.isEmpty }
        ?? []
    }

    private var trailerVideo: TMDbVideo? {
        guard let videos = loadCoordinator.details?.videos?.results else { return nil }
        let youtube = videos.filter { $0.site.lowercased() == "youtube" }

        if let trailer = youtube.first(where: { $0.type.lowercased() == "trailer" }) { return trailer }
        if let teaser = youtube.first(where: { $0.type.lowercased() == "teaser" }) { return teaser }
        return youtube.first
    }

    var trailerKey: String? {
        trailerVideo?.key
    }

    var trailerWatchURL: URL? {
        guard let key = trailerKey else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }

    var runtimeText: String? {
        MovieFactsValuePresentation.runtimeText(loadCoordinator.details?.runtime)
    }

    var taglineText: String? {
        let t = (loadCoordinator.details?.tagline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var overviewText: String? {
        let t = (loadCoordinator.details?.overview ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var releaseDateText: String? {
        guard let details = loadCoordinator.details else { return nil }
        return MovieReleaseDatePresentation.preferredReleaseDateText(
            releaseDates: details.release_dates,
            regionCode: effectiveWatchProvidersRegionCode,
            fallbackReleaseDate: details.release_date
        )
    }

    var originalTitleText: String? {
        let o = (loadCoordinator.details?.original_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return nil }
        if o.caseInsensitiveCompare(loadCoordinator.details?.title ?? "") == .orderedSame { return nil }
        if o.caseInsensitiveCompare(movie.title) == .orderedSame { return nil }
        return o
    }

    var originalLanguageText: String? {
        MovieFactsValuePresentation.originalLanguageText(loadCoordinator.details?.original_language)
    }

    var certificationText: String? {
        certificationPresentation?.text
    }

    var certificationPresentation: MovieCertificationPresentation? {
        MovieCertificationPresentation.make(
            releaseDates: loadCoordinator.details?.release_dates,
            regionCode: effectiveWatchProvidersRegionCode
        )
    }

    var factsPresentation: MovieFactsPresentation? {
        guard let details = loadCoordinator.details else { return nil }
        return MovieFactsPresentation.make(
            details: details,
            fallbackReleaseDate: details.release_date,
            displayTitle: movie.title,
            regionCode: effectiveWatchProvidersRegionCode
        )
    }

    var heroPosterURL: URL? {
        MovieMetadataPresentation.posterURL(
            path: loadCoordinator.details?.poster_path ?? movie.posterPath,
            width: .w500
        )
    }

    var heroBackdropURL: URL? {
        MovieMetadataPresentation.bestBackdropURL(
            backdropPath: loadCoordinator.details?.backdrop_path,
            images: loadCoordinator.details?.images,
            width: .w1280
        )
    }

    var heroPosterFallbackBackgroundURL: URL? {
        MovieMetadataPresentation.posterURL(
            path: loadCoordinator.details?.poster_path ?? movie.posterPath,
            width: .w342
        )
    }

    var trailerPreviewURL: URL? {
        MovieMetadataPresentation.trailerPreviewURL(
            backdropPath: loadCoordinator.details?.backdrop_path,
            images: loadCoordinator.details?.images,
            posterPath: loadCoordinator.details?.poster_path ?? movie.posterPath
        )
    }

    var collectionPresentation: MovieCollectionPresentation? {
        MovieCollectionPresentation.make(
            collectionDetails: loadCoordinator.collectionDetails,
            currentTMDbId: movie.tmdbId,
            watchedMovies: movieStore.movies,
            backlogMovies: movieStore.backlogMovies
        )
    }

    var recommendationsPresentation: MovieRecommendationsPresentation? {
        MovieRecommendationsPresentation.make(
            recommendations: loadCoordinator.recommendations,
            source: loadCoordinator.recommendationsSource,
            currentTMDbId: movie.tmdbId,
            watchedMovies: movieStore.movies,
            backlogMovies: movieStore.backlogMovies
        )
    }

    // MARK: - Bewertungen (Übersicht)

    var sortedRatings: [Rating] {
        movie.ratings.sorted {
            $0.reviewerName.localizedCaseInsensitiveCompare($1.reviewerName) == .orderedAscending
        }
    }
}
