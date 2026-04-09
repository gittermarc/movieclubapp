internal import SwiftUI

extension MovieSearchView {

    func loadRecommendationsIfNeeded(force: Bool = false) async {
        await viewModel.loadRecommendationsIfNeeded(
            query: query,
            isSearchFieldFocused: isSearchFieldFocused,
            localWatchedKeys: localWatchedKeys,
            localBacklogKeys: localBacklogKeys,
            force: force
        )
    }
}
