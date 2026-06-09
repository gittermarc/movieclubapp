internal import SwiftUI

struct MovieSearchIdleContentView: View {

    let viewState: MovieSearchViewState
    let recentQueries: [String]
    let discoveryShelves: [MovieDiscoveryShelf]
    let isLoadingDiscovery: Bool
    let discoveryError: String?

    @Binding var skeletonPulse: Bool

    let membershipState: (TMDbMovieResult) -> MovieSearchMembershipState
    let onRecentQueryTap: (String) -> Void
    let onClearHistory: () -> Void
    let onRefreshDiscovery: () -> Void
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

            if viewState.showsDiscovery {
                discoveryContent
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

    @ViewBuilder
    private var discoveryContent: some View {
        let visibleShelves = discoveryShelves.filter { $0.hasVisibleContent }

        if isLoadingDiscovery && visibleShelves.isEmpty {
            MovieSearchDiscoveryShelfView(
                shelf: MovieDiscoveryShelf(
                    kind: .personalizedRecommendations,
                    subtitle: "Wir suchen gerade frische Inspirationen für euch.",
                    results: []
                ),
                isLoading: true,
                skeletonPulse: $skeletonPulse,
                onRefresh: onRefreshDiscovery,
                cardContent: discoveryCard
            )
        } else if visibleShelves.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    Text("Inspiration")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(action: onRefreshDiscovery) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(discoveryError ?? "Noch keine Discovery-Vorschläge. Füge ein paar Filme mit TMDb-ID hinzu oder aktualisiere die Vorschläge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 4)
        } else {
            VStack(spacing: 18) {
                ForEach(visibleShelves) { shelf in
                    MovieSearchDiscoveryShelfView(
                        shelf: shelf,
                        isLoading: false,
                        skeletonPulse: $skeletonPulse,
                        onRefresh: onRefreshDiscovery,
                        cardContent: discoveryCard
                    )
                }
            }
        }
    }

    private func discoveryCard(for result: TMDbMovieResult) -> some View {
        let membership = membershipState(result)

        return MovieSearchDiscoveryCardView(
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
