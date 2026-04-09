internal import SwiftUI

extension MovieSearchView {

    // MARK: - Derived

    var canLoadMore: Bool {
        viewModel.canLoadMore(query: query)
    }

    func updateResultsModel() {
        resultsModel.update(results: viewModel.results, selectedSort: selectedSort)
    }

    var shouldShowRecommendations: Bool {
        viewModel.shouldShowRecommendations(query: query, isSearchFieldFocused: isSearchFieldFocused)
    }

    var baseHeaderSpacer: CGFloat { 22 }

    var focusedHeaderSpacer: CGFloat {
        (isSearchFieldFocused || keyboard.height > 0) ? 12 : 0
    }

    var headerTopSpacer: CGFloat { baseHeaderSpacer + focusedHeaderSpacer }

    var errorMessage: String? {
        viewModel.errorMessage
    }
}
