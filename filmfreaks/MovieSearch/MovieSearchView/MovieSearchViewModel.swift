import Combine
import Foundation

@MainActor
final class MovieSearchViewModel: ObservableObject {

    struct Dependencies {
        var searchMoviesPaged: (String, Int) async throws -> TMDbSearchResponse
        var fetchPopularMovies: (Int) async throws -> TMDbSearchResponse
        var fetchMovieRecommendations: (Int, Int) async throws -> TMDbSearchResponse
        var fetchMovieSimilar: (Int, Int) async throws -> TMDbSearchResponse
        var loadRecentQueries: () -> [String]
        var addRecentQuery: (String) -> Void
        var clearRecentQueries: () -> Void
        var loadRecommendationsCache: (TimeInterval) -> RecommendationsCacheManager.CachePayload?
        var saveRecommendationsCache: (String?, [TMDbMovieResult]) -> Void
        var clearRecommendationsCache: () -> Void
        var now: () -> Date

        static let live = Dependencies(
            searchMoviesPaged: { query, page in
                try await TMDbAPI.shared.searchMoviesPaged(query: query, page: page)
            },
            fetchPopularMovies: { page in
                try await TMDbAPI.shared.fetchPopularMovies(page: page)
            },
            fetchMovieRecommendations: { id, page in
                try await TMDbAPI.shared.fetchMovieRecommendations(id: id, page: page)
            },
            fetchMovieSimilar: { id, page in
                try await TMDbAPI.shared.fetchMovieSimilar(id: id, page: page)
            },
            loadRecentQueries: {
                SearchHistoryManager.load()
            },
            addRecentQuery: { query in
                SearchHistoryManager.add(query: query)
            },
            clearRecentQueries: {
                SearchHistoryManager.clear()
            },
            loadRecommendationsCache: { maxAge in
                RecommendationsCacheManager.load(maxAge: maxAge)
            },
            saveRecommendationsCache: { seedTitle, results in
                RecommendationsCacheManager.save(seedTitle: seedTitle, results: results)
            },
            clearRecommendationsCache: {
                RecommendationsCacheManager.clear()
            },
            now: {
                Date()
            }
        )
    }

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var results: [TMDbMovieResult] = []

    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var totalResults: Int = 0
    @Published var isLoadingMore: Bool = false

    @Published var recentQueries: [String]

    @Published var recommendations: [TMDbMovieResult] = []
    @Published var isLoadingRecommendations: Bool = false
    @Published var recommendationsError: String?
    @Published var recommendationsSeedTitle: String?
    @Published var recommendationsLastUpdated: Date?

    let recommendationsCacheMaxAge: TimeInterval
    let recommendationsFallbackToPopularIfNoSeeds: Bool

    let existingWatched: [Movie]

    var searchTask: Task<Void, Never>?
    var paginationTask: Task<Void, Never>?
    var activeSearchToken: UUID = UUID()
    var activePaginationToken: UUID = UUID()

    let dependencies: Dependencies

    init(
        existingWatched: [Movie],
        recommendationsCacheMaxAge: TimeInterval = 60 * 60 * 24,
        recommendationsFallbackToPopularIfNoSeeds: Bool = true,
        dependencies: Dependencies
    ) {
        self.existingWatched = existingWatched
        self.recommendationsCacheMaxAge = recommendationsCacheMaxAge
        self.recommendationsFallbackToPopularIfNoSeeds = recommendationsFallbackToPopularIfNoSeeds
        self.dependencies = dependencies
        self.recentQueries = dependencies.loadRecentQueries()
    }

    convenience init(
        existingWatched: [Movie],
        recommendationsCacheMaxAge: TimeInterval = 60 * 60 * 24,
        recommendationsFallbackToPopularIfNoSeeds: Bool = true
    ) {
        self.init(
            existingWatched: existingWatched,
            recommendationsCacheMaxAge: recommendationsCacheMaxAge,
            recommendationsFallbackToPopularIfNoSeeds: recommendationsFallbackToPopularIfNoSeeds,
            dependencies: .live
        )
    }

    func cancelTasks() {
        searchTask?.cancel()
        searchTask = nil
        paginationTask?.cancel()
        paginationTask = nil
        activeSearchToken = UUID()
        activePaginationToken = UUID()
    }

    func clearSearch() {
        cancelTasks()
        results = []
        errorMessage = nil
        currentPage = 1
        totalPages = 1
        totalResults = 0
        isLoading = false
        isLoadingMore = false
    }

    func clearRecentQueries() {
        dependencies.clearRecentQueries()
        recentQueries = []
    }

    func canLoadMore(query: String) -> Bool {
        currentPage < totalPages
            && !isLoading
            && !isLoadingMore
            && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func shouldShowRecommendations(query: String, isSearchFieldFocused: Bool) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty && results.isEmpty && !isLoading && !isSearchFieldFocused
    }
}
