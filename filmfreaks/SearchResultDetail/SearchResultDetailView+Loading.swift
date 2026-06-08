//
//  SearchResultDetailView+Loading.swift
//  filmfreaks
//

internal import SwiftUI

extension SearchResultDetailView {

    func reloadWatchProvidersOnly() async {
        await loadCoordinator.reloadWatchProvidersIfNeeded(
            for: result.id,
            effectiveRegionCode: effectiveWatchProvidersRegionCode
        )
    }

    func loadDetails() async {
        _ = await loadCoordinator.loadDetails(
            for: result,
            effectiveRegionCode: effectiveWatchProvidersRegionCode
        )
    }
}
