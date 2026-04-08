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

    func updateResultsModel() {
        resultsModel.update(results: results, selectedSort: selectedSort)
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
