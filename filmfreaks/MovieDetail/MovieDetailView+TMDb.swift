//
//  MovieDetailView+TMDb.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

extension MovieDetailView {

    // MARK: - TMDb Load

    @MainActor
    func loadDetails() async {
        let moviePatch = await loadCoordinator.loadDetails(
            for: movie,
            effectiveRegionCode: effectiveWatchProvidersRegionCode
        )
        if let moviePatch {
            moviePatch.apply(to: &movie)
        }
    }

    @MainActor
    func reloadWatchProvidersOnly() async {
        await loadCoordinator.reloadWatchProvidersIfNeeded(
            for: movie.tmdbId,
            effectiveRegionCode: effectiveWatchProvidersRegionCode
        )
    }
}
