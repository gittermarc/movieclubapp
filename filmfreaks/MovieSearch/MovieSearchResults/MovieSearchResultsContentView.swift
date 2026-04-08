internal import SwiftUI

struct MovieSearchResultsContentView: View {

    let viewState: MovieSearchViewState
    let errorMessage: String?
    let results: [TMDbMovieResult]
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let totalResults: Int
    let keyboardHeight: CGFloat
    let keyboardAnimationDuration: Double

    @Binding var skeletonPulse: Bool

    let membershipState: (TMDbMovieResult) -> MovieSearchMembershipState
    let onLoadMore: () -> Void
    let onOpenDetail: (TMDbMovieResult) -> Void
    let onAddToWatched: (TMDbMovieResult) -> Void
    let onAddToBacklog: (TMDbMovieResult) -> Void

    var body: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            switch viewState.primaryContent {
            case .loadingSkeleton:
                MovieSearchSkeletonResultsView(
                    pulse: $skeletonPulse,
                    keyboardHeight: keyboardHeight,
                    keyboardAnimationDuration: keyboardAnimationDuration
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        skeletonPulse.toggle()
                    }
                }

            case .noResults:
                Text("Keine Treffer. Bitte prüfe die Schreibweise.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)

            case .results:
                MovieSearchResultsListView(
                    results: results,
                    canLoadMore: canLoadMore,
                    isLoadingMore: isLoadingMore,
                    totalResults: totalResults,
                    keyboardHeight: keyboardHeight,
                    keyboardAnimationDuration: keyboardAnimationDuration,
                    onLoadMore: onLoadMore,
                    rowContent: resultCard
                )

            case .idlePlaceholder, .none:
                EmptyView()
            }
        }
    }

    private func resultCard(for result: TMDbMovieResult) -> some View {
        let membership = membershipState(result)

        return MovieSearchResultCardView(
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
