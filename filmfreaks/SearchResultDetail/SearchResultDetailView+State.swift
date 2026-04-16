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
        if let runtime = details?.runtime {
            return "\(runtime) Minuten"
        }
        return nil
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
        guard let raw = details?.release_date ?? result.release_date,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"

        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "de_DE")
        outFmt.dateFormat = "dd.MM.yyyy"

        if let date = inFmt.date(from: raw) {
            return outFmt.string(from: date)
        } else {
            return raw
        }
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
        let code = (details?.original_language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let locale = Locale(identifier: "de_DE")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    var titleText: String {
        details?.title ?? result.title
    }

    var yearText: String? {
        releaseYear(from: details?.release_date ?? result.release_date)
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
        let path = details?.poster_path ?? result.poster_path
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }
}
