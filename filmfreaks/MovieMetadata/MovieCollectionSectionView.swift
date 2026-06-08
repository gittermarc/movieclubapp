//
//  MovieCollectionSectionView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieCollectionSectionView: View {
    let presentation: MovieCollectionPresentation
    let onOpenDetail: (TMDbMovieResult) -> Void
    let onAddToBacklog: (TMDbMovieResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Teil der Reihe")
                    .font(.headline)

                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))

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
                            isCurrent: item.membershipState == .current,
                            onOpenDetail: {
                                onOpenDetail(item.result)
                            },
                            onAddToBacklog: item.membershipState == .missing ? {
                                onAddToBacklog(item.result)
                            } : nil
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
