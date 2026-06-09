//
//  MovieSearchDiscoveryShelfView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchDiscoveryShelfView<Card: View>: View {
    let shelf: MovieDiscoveryShelf
    let isLoading: Bool

    @Binding var skeletonPulse: Bool

    let onRefresh: () -> Void
    @ViewBuilder let cardContent: (TMDbMovieResult) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MovieSearchDiscoverySectionHeaderView(shelf: shelf, onRefresh: onRefresh)

            if isLoading {
                MovieSearchRecommendationsSkeletonView(pulse: $skeletonPulse)
            } else if shelf.results.isEmpty {
                if let error = shelf.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(shelf.results) { result in
                            cardContent(result)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                }
            }

            if let lastUpdated = shelf.lastUpdated,
               !isLoading,
               !shelf.results.isEmpty {
                Text("Zuletzt aktualisiert: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
}
