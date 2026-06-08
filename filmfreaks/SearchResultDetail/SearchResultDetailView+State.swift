//
//  SearchResultDetailView+State.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

extension SearchResultDetailView {

    // MARK: - Watch Providers Region

    /// Effektives Land für Watch Providers (leer == automatisch/Device)
    var effectiveWatchProvidersRegionCode: String {
        WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
        ?? WatchProvidersRegionSettings.deviceRegionCode()
    }

    var isWatchProvidersRegionAutomatic: Bool {
        watchProvidersRegionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }


    var details: TMDbMovieDetails? {
        loadCoordinator.details
    }

    var isLoading: Bool {
        loadCoordinator.isLoadingDetails
    }

    var errorMessage: String? {
        loadCoordinator.detailsError
    }

    var watchProvidersCountry: TMDbWatchProvidersCountry? {
        loadCoordinator.watchProvidersCountry
    }

    var watchProvidersLink: URL? {
        loadCoordinator.watchProvidersLink
    }

    var isLoadingWatchProviders: Bool {
        loadCoordinator.isLoadingWatchProviders
    }

    var didLoadWatchProviders: Bool {
        loadCoordinator.didLoadWatchProviders
    }

    // MARK: - Metadaten aus TMDb (wie MovieDetailView)

    var director: String? {
        details?.credits?.crew.first(where: { ($0.job ?? "").lowercased() == "director" })?.name
    }

    var castList: [TMDbCast] {
        Array(details?.credits?.cast.prefix(12) ?? [])
    }

    var keywordNames: [String] {
        MovieMetadataTagPresentation.normalizedNames(
            from: details?.keywords?.allKeywords.map(\.name) ?? []
        )
    }

    var genreNames: [String] {
        details?.genres?
            .map { $0.name }
            .filter { !$0.isEmpty }
        ?? []
    }

    var runtimeText: String? {
        MovieFactsValuePresentation.runtimeText(details?.runtime)
    }

    var taglineText: String? {
        let t = (details?.tagline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var overviewText: String? {
        let t = (details?.overview ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var releaseDateText: String? {
        guard let details else {
            return MovieMetadataPresentation.formattedReleaseDate(result.release_date)
        }

        return MovieReleaseDatePresentation.preferredReleaseDateText(
            releaseDates: details.release_dates,
            regionCode: effectiveWatchProvidersRegionCode,
            fallbackReleaseDate: details.release_date ?? result.release_date
        )
    }

    var originalTitleText: String? {
        let o = (details?.original_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return nil }
        // Nur anzeigen, wenn er sich sinnvoll unterscheidet
        if o.caseInsensitiveCompare(details?.title ?? "") == .orderedSame { return nil }
        if o.caseInsensitiveCompare(result.title) == .orderedSame { return nil }
        return o
    }

    var originalLanguageText: String? {
        MovieFactsValuePresentation.originalLanguageText(details?.original_language)
    }

    var titleText: String {
        details?.title ?? result.title
    }

    var yearText: String? {
        releaseYear(from: details?.release_date ?? result.release_date)
    }

    var certificationText: String? {
        certificationPresentation?.text
    }

    var certificationPresentation: MovieCertificationPresentation? {
        MovieCertificationPresentation.make(
            releaseDates: details?.release_dates,
            regionCode: effectiveWatchProvidersRegionCode
        )
    }

    var factsPresentation: MovieFactsPresentation? {
        guard let details else { return nil }
        return MovieFactsPresentation.make(
            details: details,
            fallbackReleaseDate: details.release_date ?? result.release_date,
            displayTitle: result.title,
            regionCode: effectiveWatchProvidersRegionCode
        )
    }

    var heroBackdropURL: URL? {
        MovieMetadataPresentation.bestBackdropURL(
            backdropPath: details?.backdrop_path ?? result.backdrop_path,
            images: details?.images,
            width: .w1280
        )
    }

    var trailerPreviewURL: URL? {
        MovieMetadataPresentation.trailerPreviewURL(
            backdropPath: details?.backdrop_path ?? result.backdrop_path,
            images: details?.images,
            posterPath: details?.poster_path ?? result.poster_path
        )
    }

    // MARK: - Trailer

    /// Trailer: wir arbeiten mit Key (für watch-url)
    var trailerVideo: TMDbVideo? {
        guard let videos = details?.videos?.results else { return nil }
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

    // MARK: - Helper

    var posterURL: URL? {
        MovieMetadataPresentation.posterURL(
            path: details?.poster_path ?? result.poster_path,
            width: .w500
        )
    }

    func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }
}
