import Combine
import Foundation

@MainActor
final class MovieSearchViewModel: ObservableObject {

    nonisolated struct Dependencies {
        var searchMoviesPaged: (String, Int) async throws -> TMDbSearchResponse
        var loadRecentQueries: () -> [String]
        var addRecentQuery: (String) -> Void
        var clearRecentQueries: () -> Void
        var loadDiscoveryShelves: (MovieDiscoveryRequest, Bool) async -> MovieDiscoveryLoadResult
        var now: () -> Date

        nonisolated static var live: Dependencies {
            let discoveryService = MovieDiscoveryService(
                dependencies: .live,
                cacheStore: TMDbMetadataCacheFileStore()
            )
            return Dependencies(
                searchMoviesPaged: { query, page in
                    try await TMDbAPI.shared.searchMoviesPaged(query: query, page: page)
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
                loadDiscoveryShelves: { request, forceRefresh in
                    await discoveryService.loadShelves(request: request, forceRefresh: forceRefresh)
                },
                now: {
                    Date()
                }
            )
        }
    }

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var results: [TMDbMovieResult] = []

    @Published var currentPage: Int = 1
    @Published var totalPages: Int = 1
    @Published var totalResults: Int = 0
    @Published var isLoadingMore: Bool = false

    @Published var recentQueries: [String]

    @Published var discoveryShelves: [MovieDiscoveryShelf] = []
    @Published var isLoadingDiscovery: Bool = false
    @Published var discoveryError: String?

    let existingWatched: [Movie]
    let existingBacklog: [Movie]

    var searchTask: Task<Void, Never>?
    var paginationTask: Task<Void, Never>?
    var discoveryTask: Task<Void, Never>?
    var discoveryRefreshTask: Task<Void, Never>?
    var activeSearchToken: UUID = UUID()
    var activePaginationToken: UUID = UUID()
    var activeDiscoveryToken: UUID = UUID()

    let dependencies: Dependencies

    init(
        existingWatched: [Movie],
        existingBacklog: [Movie] = [],
        dependencies: Dependencies
    ) {
        self.existingWatched = existingWatched
        self.existingBacklog = existingBacklog
        self.dependencies = dependencies
        self.recentQueries = dependencies.loadRecentQueries()
    }

    convenience init(
        existingWatched: [Movie],
        existingBacklog: [Movie] = []
    ) {
        self.init(
            existingWatched: existingWatched,
            existingBacklog: existingBacklog,
            dependencies: .live
        )
    }

    func cancelTasks() {
        searchTask?.cancel()
        searchTask = nil
        paginationTask?.cancel()
        paginationTask = nil
        discoveryTask?.cancel()
        discoveryTask = nil
        discoveryRefreshTask?.cancel()
        discoveryRefreshTask = nil
        activeSearchToken = UUID()
        activePaginationToken = UUID()
        activeDiscoveryToken = UUID()
    }

    func clearSearch() {
        cancelSearchWork()
        results = []
        errorMessage = nil
        currentPage = 1
        totalPages = 1
        totalResults = 0
        isLoading = false
        isLoadingMore = false
    }

    func cancelSearchWork() {
        searchTask?.cancel()
        searchTask = nil
        paginationTask?.cancel()
        paginationTask = nil
        activeSearchToken = UUID()
        activePaginationToken = UUID()
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

    func shouldShowDiscovery(query: String, isSearchFieldFocused: Bool) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty && results.isEmpty && !isLoading && !isSearchFieldFocused
    }

    func shouldShowRecommendations(query: String, isSearchFieldFocused: Bool) -> Bool {
        shouldShowDiscovery(query: query, isSearchFieldFocused: isSearchFieldFocused)
    }
}
