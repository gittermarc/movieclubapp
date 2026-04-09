internal import SwiftUI

extension MovieSearchView {

    func cancelSearchTasks() {
        viewModel.cancelTasks()
    }

    func clearSearch() {
        query = ""
        selectedSort = .relevance
        viewModel.clearSearch()
    }

    func startSearch(reset: Bool) {
        viewModel.startSearch(query: query, reset: reset)
    }

    func startLoadMore() {
        viewModel.startLoadMore(query: query)
    }
}
