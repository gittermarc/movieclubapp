internal import SwiftUI

extension MovieSearchView {

    var viewState: MovieSearchViewState {
        MovieSearchViewState.resolve(
            query: query,
            recentQueries: viewModel.recentQueries,
            isLoading: viewModel.isLoading,
            hasResults: !resultsModel.sortedResults.isEmpty,
            isSearchFieldFocused: isSearchFieldFocused,
            shouldShowRecommendations: shouldShowRecommendations
        )
    }

    func membershipState(for result: TMDbMovieResult) -> MovieSearchMembershipState {
        let key = MovieSearchMapper.key(for: result)
        return MovieSearchMembershipState(
            isInWatched: localWatchedKeys.contains(key),
            isInBacklog: localBacklogKeys.contains(key)
        )
    }

    func handleRecentQueryTap(_ term: String) {
        query = term
        startSearch(reset: true)
    }

    func handleClearHistory() {
        viewModel.clearRecentQueries()
    }

    func handleRecommendationsRefresh() {
        Task {
            await loadRecommendationsIfNeeded(force: true)
        }
    }

    func handleAddToWatched(_ result: TMDbMovieResult) {
        let key = MovieSearchMapper.key(for: result)
        guard !localWatchedKeys.contains(key) else { return }

        let movie = MovieSearchMapper.convertToMovie(result)
        onAddToWatched(movie)
        localWatchedKeys.insert(key)
        showConfirmation("Zu „Gesehen“ hinzugefügt")
    }

    func handleAddToBacklog(_ result: TMDbMovieResult) {
        let key = MovieSearchMapper.key(for: result)
        guard !localBacklogKeys.contains(key) else { return }

        let movie = MovieSearchMapper.convertToMovie(result)
        onAddToBacklog(movie)
        localBacklogKeys.insert(key)
        showConfirmation("Zum Backlog hinzugefügt")
    }

    func handleDetailAddToWatched(_ movie: Movie, key: String) {
        onAddToWatched(movie)
        localWatchedKeys.insert(key)
    }

    func handleDetailAddToBacklog(_ movie: Movie, key: String) {
        onAddToBacklog(movie)
        localBacklogKeys.insert(key)
    }
}
