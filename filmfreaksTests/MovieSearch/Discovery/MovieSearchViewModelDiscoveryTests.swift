import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieSearchViewModelDiscoveryTests {

    @Test func discoveryDoesNotLoadWhileQueryIsNotEmpty() async {
        var calls = 0
        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: dependencies { _, _ in
                calls += 1
                return MovieDiscoveryLoadResult(shelves: [], usedStaleCache: false)
            }
        )

        await viewModel.loadDiscoveryIfNeeded(
            query: "Alien",
            isSearchFieldFocused: false,
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: "DE"
        )

        #expect(calls == 0)
        #expect(viewModel.discoveryShelves.isEmpty)
    }

    @Test func discoveryDoesNotLoadWhileSearchFieldIsFocused() async {
        var calls = 0
        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: dependencies { _, _ in
                calls += 1
                return MovieDiscoveryLoadResult(shelves: [], usedStaleCache: false)
            }
        )

        await viewModel.loadDiscoveryIfNeeded(
            query: "",
            isSearchFieldFocused: true,
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: "DE"
        )

        #expect(calls == 0)
        #expect(viewModel.discoveryShelves.isEmpty)
    }

    @Test func forceRefreshPassesThroughToDiscoveryDependency() async {
        var forceValues: [Bool] = []
        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: dependencies { _, force in
                forceValues.append(force)
                return MovieDiscoveryLoadResult(
                    shelves: [MovieDiscoveryShelf(kind: .popular, results: [])],
                    usedStaleCache: false
                )
            }
        )

        await viewModel.loadDiscoveryIfNeeded(
            query: "",
            isSearchFieldFocused: false,
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: "DE",
            force: true
        )

        #expect(forceValues == [true])
    }

    private func dependencies(
        loadDiscoveryShelves: @escaping (MovieDiscoveryRequest, Bool) async -> MovieDiscoveryLoadResult
    ) -> MovieSearchViewModel.Dependencies {
        MovieSearchViewModel.Dependencies(
            searchMoviesPaged: { _, _ in
                TMDbSearchResponse(page: 1, results: [], total_pages: 1, total_results: 0)
            },
            loadRecentQueries: { [] },
            addRecentQuery: { _ in },
            clearRecentQueries: { },
            loadDiscoveryShelves: loadDiscoveryShelves,
            now: { Date() }
        )
    }
}
