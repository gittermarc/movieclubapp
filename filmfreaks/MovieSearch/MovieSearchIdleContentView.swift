internal import SwiftUI

struct MovieSearchIdleContentView: View {

    let viewState: MovieSearchViewState
    let recentQueries: [String]
    let recommendations: [TMDbMovieResult]
    let isLoadingRecommendations: Bool
    let recommendationsError: String?
    let recommendationsSeedTitle: String?
    let recommendationsLastUpdated: Date?

    @Binding var skeletonPulse: Bool

    let membershipState: (TMDbMovieResult) -> MovieSearchMembershipState
    let onRecentQueryTap: (String) -> Void
    let onClearHistory: () -> Void
    let onRefreshRecommendations: () -> Void
    let onOpenDetail: (TMDbMovieResult) -> Void
    let onAddToWatched: (TMDbMovieResult) -> Void
    let onAddToBacklog: (TMDbMovieResult) -> Void

    var body: some View {
        Group {
            if viewState.showsRecentQueries {
                MovieSearchRecentQueriesView(
                    recentQueries: recentQueries,
                    onTap: onRecentQueryTap,
                    onClearHistory: onClearHistory
                )
            }

            if viewState.showsRecommendations {
                MovieSearchRecommendationsSectionView(
                    recommendations: recommendations,
                    isLoading: isLoadingRecommendations,
                    errorMessage: recommendationsError,
                    seedTitle: recommendationsSeedTitle,
                    lastUpdated: recommendationsLastUpdated,
                    skeletonPulse: $skeletonPulse,
                    onRefresh: onRefreshRecommendations,
                    cardContent: recommendationCard
                )
            }

            if viewState.primaryContent == .idlePlaceholder {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Suche nach Filmtiteln auf TMDb")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            }
        }
    }

    private func recommendationCard(for result: TMDbMovieResult) -> some View {
        let membership = membershipState(result)

        return MovieSearchRecommendationCardView(
            result: result,
            isInWatched: membership.isInWatched,
            isInBacklog: membership.isInBacklog,
            onOpenDetail: {
                onOpenDetail(result)
            },
            onAddToWatched: {
                onAddToWatched(result)
            },
            onAddToBacklog: {
                onAddToBacklog(result)
            }
        )
    }
}
