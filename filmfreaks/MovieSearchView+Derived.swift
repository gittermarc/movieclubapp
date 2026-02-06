//
//  MovieSearchView+Derived.swift
//  filmfreaks
//

internal import SwiftUI

extension MovieSearchView {

    // MARK: - Derived

    var canLoadMore: Bool {
        currentPage < totalPages
        && !isLoading
        && !isLoadingMore
        && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var sortedResults: [TMDbMovieResult] {
        switch selectedSort {
        case .relevance:
            // TMDb-Reihenfolge, wie geliefert
            return results

        case .titleAZ:
            return results.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        case .titleZA:
            return results.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }

        case .yearNewest:
            return results.sorted { (yearInt(from: $0.release_date) ?? -1) > (yearInt(from: $1.release_date) ?? -1) }

        case .yearOldest:
            return results.sorted { (yearInt(from: $0.release_date) ?? Int.max) < (yearInt(from: $1.release_date) ?? Int.max) }

        case .ratingHigh:
            return results.sorted { $0.vote_average > $1.vote_average }

        case .ratingLow:
            return results.sorted { $0.vote_average < $1.vote_average }
        }
    }

    var shouldShowRecommendations: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Nur im „Idle“-Zustand: keine Suche aktiv und keine Ergebnisse sichtbar
        return trimmed.isEmpty && results.isEmpty && !isLoading && !isSearchFieldFocused
    }

    /// ✅ Basis-Abstand, damit das Suchfeld schon im „Idle“-Zustand weiter unten sitzt.
    /// Hintergrund: Beim ersten Fokus-Frame kann SwiftUI den `safeAreaInset` kurz neu vermessen
    /// und der Header rutscht für einen Moment unter den Inline-Titel. Mit diesem Puffer passiert das nicht.
    var baseHeaderSpacer: CGFloat { 22 }

    /// ✅ Extra Luft, sobald das Suchfeld Fokus hat (oder das Keyboard sichtbar ist).
    var focusedHeaderSpacer: CGFloat {
        (isSearchFieldFocused || keyboard.height > 0) ? 12 : 0
    }

    /// Gesamtabstand über dem Suchfeld (Basis + Fokus)
    var headerTopSpacer: CGFloat { baseHeaderSpacer + focusedHeaderSpacer }
}
