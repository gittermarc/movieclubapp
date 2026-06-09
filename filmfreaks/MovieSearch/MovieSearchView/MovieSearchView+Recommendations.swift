internal import SwiftUI

extension MovieSearchView {

    var effectiveDiscoveryRegionCode: String {
        WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
        ?? WatchProvidersRegionSettings.deviceRegionCode()
    }

    func loadDiscoveryIfNeeded(force: Bool = false) async {
        await viewModel.loadDiscoveryIfNeeded(
            query: query,
            isSearchFieldFocused: isSearchFieldFocused,
            localWatchedKeys: localWatchedKeys,
            localBacklogKeys: localBacklogKeys,
            regionCode: effectiveDiscoveryRegionCode,
            force: force
        )
    }

    func loadRecommendationsIfNeeded(force: Bool = false) async {
        await loadDiscoveryIfNeeded(force: force)
    }
}
