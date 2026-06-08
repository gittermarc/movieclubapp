//
//  MovieRecommendationsSectionView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieRecommendationsSectionView: View {
    let presentation: MovieRecommendationsPresentation
    let onOpenDetail: (TMDbMovieResult) -> Void
    let onAddToBacklog: (TMDbMovieResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.headline)

                if let subtitle = presentation.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(presentation.items) { item in
                        MovieRecommendationCardView(
                            title: item.title,
                            yearText: item.yearText,
                            ratingText: item.ratingText,
                            posterURL: item.posterURL,
                            backdropURL: item.backdropURL,
                            membershipState: item.membershipState,
                            showsMembershipBadge: false,
                            isCurrent: false,
                            onOpenDetail: {
                                onOpenDetail(item.result)
                            },
                            onAddToBacklog: {
                                onAddToBacklog(item.result)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}
