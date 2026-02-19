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

    /// Freitext-Suche innerhalb der Liste (Titel/Jahr/Location/SuggestedBy + optional Cast/Genres/Keywords).
    /// Token-basiert: alle Wörter müssen vorkommen ("ring 2001" findet auch "Herr der Ringe (2001)").
    func passesListSearch(_ movie: Movie, isBacklog: Bool) -> Bool {
        let raw = (isBacklog ? backlogSearchText : watchedSearchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = movieItemsModel.searchIndex.normalizedTokens(for: raw)
        return movieItemsModel.searchIndex.matches(movie: movie, tokens: tokens)
    }
}
