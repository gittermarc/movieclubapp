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

    var keywordsText: String? {
        guard let all = loadCoordinator.details?.keywords?.allKeywords, !all.isEmpty else { return nil }
        let names = all.map { $0.name }
        return names.joined(separator: ", ")
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
        if let runtime = loadCoordinator.details?.runtime {
            return "\(runtime) Minuten"
        }
        return nil
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
        guard let raw = loadCoordinator.details?.release_date, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
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
        let o = (loadCoordinator.details?.original_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return nil }
        if o.caseInsensitiveCompare(loadCoordinator.details?.title ?? "") == .orderedSame { return nil }
        if o.caseInsensitiveCompare(movie.title) == .orderedSame { return nil }
        return o
    }

    var originalLanguageText: String? {
        let code = (loadCoordinator.details?.original_language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let locale = Locale(identifier: "de_DE")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    // MARK: - Bewertungen (Übersicht)

    var sortedRatings: [Rating] {
        movie.ratings.sorted {
            $0.reviewerName.localizedCaseInsensitiveCompare($1.reviewerName) == .orderedAscending
        }
    }
}
