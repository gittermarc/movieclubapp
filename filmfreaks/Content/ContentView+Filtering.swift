//
//  ContentView+Filtering.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

extension ContentView {

    // MARK: - User Filter

    /// Filter-Logik für watched-Liste: nach Bewertungen des Users
    func passesUserFilterForWatched(_ movie: Movie) -> Bool {
        guard let user = filterByUser else {
            return true
        }
        return movie.ratings.contains { rating in
            if let rid = rating.reviewerId {
                return rid == user.id
            }
            // Legacy/local fallback: compare by display name
            return rating.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(user.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    /// Filter-Logik für Backlog: nach „Vorgeschlagen von“
    func passesUserFilterForBacklog(_ movie: Movie) -> Bool {
        guard let user = filterByUser else {
            return true
        }
        guard let sugg = movie.suggestedBy else { return false }
        return sugg.lowercased() == user.name.lowercased()
    }

    // MARK: - In-List Search (Textfilter)

    private func normalizedSearchString(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    /// Freitext-Suche innerhalb der Liste (Titel/Jahr/Location/SuggestedBy + optional Cast/Genres/Keywords).
    /// Token-basiert: alle Wörter müssen vorkommen ("ring 2001" findet auch "Herr der Ringe (2001)").
    func passesListSearch(_ movie: Movie, isBacklog: Bool) -> Bool {
        let raw = (isBacklog ? backlogSearchText : watchedSearchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !raw.isEmpty else { return true }

        let tokens = normalizedSearchString(raw)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return true }

        var fields: [String] = [movie.title, movie.year]

        if let location = movie.watchedLocation, !location.isEmpty {
            fields.append(location)
        }

        if let suggestedBy = movie.suggestedBy, !suggestedBy.isEmpty {
            fields.append(suggestedBy)
        }

        if let cast = movie.cast, !cast.isEmpty {
            fields.append(cast.map { $0.name }.joined(separator: " "))
        }

        if let directors = movie.directors, !directors.isEmpty {
            fields.append(directors.map { $0.name }.joined(separator: " "))
        }

        if let genres = movie.genres, !genres.isEmpty {
            fields.append(genres.joined(separator: " "))
        }

        if let keywords = movie.keywords, !keywords.isEmpty {
            fields.append(keywords.joined(separator: " "))
        }

        let haystack = normalizedSearchString(fields.joined(separator: " "))
        return tokens.allSatisfy { haystack.contains($0) }
    }
}
