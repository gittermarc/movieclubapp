import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieSearchViewModelTests {

    @Test func recommendationFallbackUsesPopularMoviesWhenNoSeedsExist() async {
        var popularCalls = 0
        let now = makeDate(day: 9)
        var savedCache: (String?, [TMDbMovieResult])?

        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: makeDependencies(
                fetchPopularMovies: { page in
                    popularCalls += 1
                    #expect(page == 1)
                    return self.makeResponse(
                        page: 1,
                        totalPages: 1,
                        totalResults: 2,
                        results: [
                            self.makeResult(id: 10, title: "Popular One"),
                            self.makeResult(id: 11, title: "Popular Two")
                        ]
                    )
                },
                saveRecommendationsCache: { seedTitle, results in
                    savedCache = (seedTitle, results)
                },
                now: { now }
            )
        )

        await viewModel.loadRecommendationsIfNeeded(
            query: "",
            isSearchFieldFocused: false,
            localWatchedKeys: [],
            localBacklogKeys: []
        )

        #expect(popularCalls == 1)
        #expect(viewModel.recommendations.map(\.id) == [10, 11])
        #expect(viewModel.recommendationsSeedTitle == nil)
        #expect(viewModel.recommendationsLastUpdated == now)
        #expect(savedCache?.0 == nil)
        #expect(savedCache?.1.map(\.id) == [10, 11])
    }

    @Test func newSearchResetsResultsAndPaginationState() async {
        var calls: [(String, Int)] = []

        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: makeDependencies(
                searchMoviesPaged: { query, page in
                    calls.append((query, page))
                    switch (query, page) {
                    case ("Alien", 1):
                        return self.makeResponse(
                            page: 1,
                            totalPages: 3,
                            totalResults: 6,
                            results: [self.makeResult(id: 1, title: "Alien")]
                        )
                    case ("Alien", 2):
                        return self.makeResponse(
                            page: 2,
                            totalPages: 3,
                            totalResults: 6,
                            results: [self.makeResult(id: 2, title: "Aliens")]
                        )
                    case ("Blade Runner", 1):
                        return self.makeResponse(
                            page: 1,
                            totalPages: 1,
                            totalResults: 1,
                            results: [self.makeResult(id: 9, title: "Blade Runner")]
                        )
                    default:
                        Issue.record("Unexpected search call: \(query) page \(page)")
                        return self.makeResponse(page: 1, totalPages: 1, totalResults: 0, results: [])
                    }
                }
            )
        )

        viewModel.startSearch(query: "Alien", reset: true)
        await waitForUpdates()
        viewModel.startLoadMore(query: "Alien")
        await waitForUpdates()

        #expect(viewModel.results.map(\.id) == [1, 2])
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.totalPages == 3)

        viewModel.startSearch(query: "Blade Runner", reset: true)
        await waitForUpdates()

        #expect(viewModel.results.map(\.id) == [9])
        #expect(viewModel.currentPage == 1)
        #expect(viewModel.totalPages == 1)
        #expect(viewModel.totalResults == 1)
        #expect(viewModel.isLoadingMore == false)
        #expect(calls.map { "\($0.0)#\($0.1)" } == ["Alien#1", "Alien#2", "Blade Runner#1"])
    }

    @Test func paginationLoadsNextPageOnlyWhenAllowed() async {
        var calls: [(String, Int)] = []

        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: makeDependencies(
                searchMoviesPaged: { query, page in
                    calls.append((query, page))
                    switch page {
                    case 1:
                        return self.makeResponse(
                            page: 1,
                            totalPages: 2,
                            totalResults: 3,
                            results: [self.makeResult(id: 1, title: "First")]
                        )
                    case 2:
                        return self.makeResponse(
                            page: 2,
                            totalPages: 2,
                            totalResults: 3,
                            results: [
                                self.makeResult(id: 2, title: "Second"),
                                self.makeResult(id: 3, title: "Third")
                            ]
                        )
                    default:
                        Issue.record("Unexpected page \(page)")
                        return self.makeResponse(page: 1, totalPages: 1, totalResults: 0, results: [])
                    }
                }
            )
        )

        viewModel.startLoadMore(query: "   ")
        await waitForUpdates(count: 1)
        #expect(calls.isEmpty)

        viewModel.startSearch(query: "Matrix", reset: true)
        await waitForUpdates()
        viewModel.startLoadMore(query: "Matrix")
        await waitForUpdates()
        viewModel.startLoadMore(query: "Matrix")
        await waitForUpdates(count: 1)

        #expect(calls.map { "\($0.0)#\($0.1)" } == ["Matrix#1", "Matrix#2"])
        #expect(viewModel.results.map(\.id) == [1, 2, 3])
        #expect(viewModel.currentPage == 2)
        #expect(viewModel.totalPages == 2)
    }

    @Test func staleSearchResultsDoNotOverrideNewerSearch() async {
        let viewModel = MovieSearchViewModel(
            existingWatched: [],
            dependencies: makeDependencies(
                searchMoviesPaged: { query, _ in
                    if query == "Old Query" {
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        return self.makeResponse(
                            page: 1,
                            totalPages: 1,
                            totalResults: 1,
                            results: [self.makeResult(id: 1, title: "Old Result")]
                        )
                    }

                    return self.makeResponse(
                        page: 1,
                        totalPages: 1,
                        totalResults: 1,
                        results: [self.makeResult(id: 2, title: "New Result")]
                    )
                }
            )
        )

        viewModel.startSearch(query: "Old Query", reset: true)
        viewModel.startSearch(query: "New Query", reset: true)
        await waitForUpdates(count: 6)

        #expect(viewModel.results.map(\.id) == [2])
        #expect(viewModel.results.map(\.title) == ["New Result"])
    }

    private func makeDependencies(
        searchMoviesPaged: ((String, Int) async throws -> TMDbSearchResponse)? = nil,
        fetchPopularMovies: ((Int) async throws -> TMDbSearchResponse)? = nil,
        fetchMovieRecommendations: ((Int, Int) async throws -> TMDbSearchResponse)? = nil,
        fetchMovieSimilar: ((Int, Int) async throws -> TMDbSearchResponse)? = nil,
        loadRecentQueries: (() -> [String])? = nil,
        addRecentQuery: ((String) -> Void)? = nil,
        clearRecentQueries: (() -> Void)? = nil,
        loadRecommendationsCache: ((TimeInterval) -> RecommendationsCacheManager.CachePayload?)? = nil,
        saveRecommendationsCache: ((String?, [TMDbMovieResult]) -> Void)? = nil,
        clearRecommendationsCache: (() -> Void)? = nil,
        now: (() -> Date)? = nil
    ) -> MovieSearchViewModel.Dependencies {
        MovieSearchViewModel.Dependencies(
            searchMoviesPaged: searchMoviesPaged ?? { _, _ in
                self.makeResponse(page: 1, totalPages: 1, totalResults: 0, results: [])
            },
            fetchPopularMovies: fetchPopularMovies ?? { _ in
                self.makeResponse(page: 1, totalPages: 1, totalResults: 0, results: [])
            },
            fetchMovieRecommendations: fetchMovieRecommendations ?? { _, _ in
                self.makeResponse(page: 1, totalPages: 1, totalResults: 0, results: [])
            },
            fetchMovieSimilar: fetchMovieSimilar ?? { _, _ in
                self.makeResponse(page: 1, totalPages: 1, totalResults: 0, results: [])
            },
            loadRecentQueries: loadRecentQueries ?? { [] },
            addRecentQuery: addRecentQuery ?? { _ in },
            clearRecentQueries: clearRecentQueries ?? { },
            loadRecommendationsCache: loadRecommendationsCache ?? { _ in nil },
            saveRecommendationsCache: saveRecommendationsCache ?? { _, _ in },
            clearRecommendationsCache: clearRecommendationsCache ?? { },
            now: now ?? { Date() }
        )
    }

    private func makeResponse(
        page: Int,
        totalPages: Int,
        totalResults: Int,
        results: [TMDbMovieResult]
    ) -> TMDbSearchResponse {
        TMDbSearchResponse(
            page: page,
            results: results,
            total_pages: totalPages,
            total_results: totalResults
        )
    }

    private func makeResult(id: Int, title: String) -> TMDbMovieResult {
        TMDbMovieResult(
            id: id,
            title: title,
            release_date: "2024-01-01",
            vote_average: 7.0,
            poster_path: nil
        )
    }

    private func makeDate(day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: day,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }

    private func waitForUpdates(count: Int = 4) async {
        for _ in 0..<count {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
