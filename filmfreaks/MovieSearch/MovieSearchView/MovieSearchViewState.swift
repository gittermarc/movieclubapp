import Foundation

struct MovieSearchMembershipState: Equatable {
    let isInWatched: Bool
    let isInBacklog: Bool
}

struct MovieSearchViewState: Equatable {

    enum PrimaryContent: Equatable {
        case loadingSkeleton
        case noResults
        case results
        case idlePlaceholder
        case none
    }

    let showsRecentQueries: Bool
    let showsDiscovery: Bool
    let primaryContent: PrimaryContent

    var showsRecommendations: Bool { showsDiscovery }

    var showsIdleSurface: Bool {
        showsRecentQueries || showsDiscovery || primaryContent == .idlePlaceholder
    }

    static func resolve(
        query: String,
        recentQueries: [String],
        isLoading: Bool,
        hasResults: Bool,
        isSearchFieldFocused: Bool,
        shouldShowRecommendations: Bool
    ) -> MovieSearchViewState {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let showsRecentQueries = trimmedQuery.isEmpty && !recentQueries.isEmpty

        let primaryContent: PrimaryContent
        if isLoading && !hasResults {
            primaryContent = .loadingSkeleton
        } else if !hasResults && !isLoading && !trimmedQuery.isEmpty {
            primaryContent = .noResults
        } else if hasResults {
            primaryContent = .results
        } else if !isLoading && trimmedQuery.isEmpty && recentQueries.isEmpty && !isSearchFieldFocused && !shouldShowRecommendations {
            primaryContent = .idlePlaceholder
        } else {
            primaryContent = .none
        }

        return MovieSearchViewState(
            showsRecentQueries: showsRecentQueries,
            showsDiscovery: shouldShowRecommendations,
            primaryContent: primaryContent
        )
    }
}
