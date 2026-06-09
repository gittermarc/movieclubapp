import Testing
@testable import filmfreaks

struct MovieSearchViewStateTests {

    @Test func showsRecentQueriesOnlyWhenQueryIsEmpty() {
        let state = MovieSearchViewState.resolve(
            query: "   ",
            recentQueries: ["Alien"],
            isLoading: false,
            hasResults: false,
            isSearchFieldFocused: false,
            shouldShowRecommendations: true
        )

        #expect(state.showsRecentQueries)
        #expect(state.showsRecommendations)
        #expect(state.primaryContent == .none)
    }

    @Test func loadingSkeletonWinsWhenLoadingWithoutResults() {
        let state = MovieSearchViewState.resolve(
            query: "Dune",
            recentQueries: [],
            isLoading: true,
            hasResults: false,
            isSearchFieldFocused: false,
            shouldShowRecommendations: false
        )

        #expect(state.primaryContent == .loadingSkeleton)
    }

    @Test func noResultsShownForFinishedSearchWithoutMatches() {
        let state = MovieSearchViewState.resolve(
            query: "Dune",
            recentQueries: [],
            isLoading: false,
            hasResults: false,
            isSearchFieldFocused: false,
            shouldShowRecommendations: false
        )

        #expect(state.primaryContent == .noResults)
    }

    @Test func resultsStateShownWhenSortedResultsExist() {
        let state = MovieSearchViewState.resolve(
            query: "Dune",
            recentQueries: [],
            isLoading: false,
            hasResults: true,
            isSearchFieldFocused: false,
            shouldShowRecommendations: false
        )

        #expect(state.primaryContent == .results)
    }

    @Test func idlePlaceholderShownOnlyForEmptyIdleState() {
        let state = MovieSearchViewState.resolve(
            query: "",
            recentQueries: [],
            isLoading: false,
            hasResults: false,
            isSearchFieldFocused: false,
            shouldShowRecommendations: false
        )

        #expect(state.primaryContent == .idlePlaceholder)
        #expect(state.showsIdleSurface)
    }

    @Test func focusedEmptySearchDoesNotShowIdlePlaceholder() {
        let state = MovieSearchViewState.resolve(
            query: "",
            recentQueries: [],
            isLoading: false,
            hasResults: false,
            isSearchFieldFocused: true,
            shouldShowRecommendations: false
        )

        #expect(state.primaryContent == .none)
        #expect(!state.showsIdleSurface)
    }

    @Test func discoveryUsesIdleSurface() {
        let state = MovieSearchViewState.resolve(
            query: "",
            recentQueries: [],
            isLoading: false,
            hasResults: false,
            isSearchFieldFocused: false,
            shouldShowRecommendations: true
        )

        #expect(state.showsDiscovery)
        #expect(state.showsIdleSurface)
    }

    @Test func searchResultsDoNotUseIdleSurface() {
        let state = MovieSearchViewState.resolve(
            query: "Dune",
            recentQueries: ["Alien"],
            isLoading: false,
            hasResults: true,
            isSearchFieldFocused: false,
            shouldShowRecommendations: false
        )

        #expect(state.primaryContent == .results)
        #expect(!state.showsIdleSurface)
    }
}
