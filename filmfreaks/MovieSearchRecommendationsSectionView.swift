//
//  MovieSearchRecommendationsSectionView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchRecommendationsSectionView<Card: View>: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let recommendations: [TMDbMovieResult]
    let isLoading: Bool
    let errorMessage: String?
    let seedTitle: String?
    let lastUpdated: Date?

    @Binding var skeletonPulse: Bool

    let onRefresh: () -> Void
    @ViewBuilder let cardContent: (TMDbMovieResult) -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    Text("Inspiration")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Aktualisieren")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(displaySettings.tintSoftBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            if let seedTitle, !seedTitle.isEmpty {
                Text("Basierend auf „\(seedTitle)“ und ähnlichen Filmen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Text("Filme, die zu deinem Geschmack passen könnten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if isLoading {
                MovieSearchRecommendationsSkeletonView(pulse: $skeletonPulse)
            } else if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            } else if recommendations.isEmpty {
                Text("Noch keine Empfehlungen. Füge erst ein paar Filme zu „Gesehen“ hinzu (mit TMDb-ID), dann wird’s hier spannend. 🍿")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendations) { result in
                            cardContent(result)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                }
            }

            if let lastUpdated,
               !isLoading,
               errorMessage == nil,
               !recommendations.isEmpty {
                Text("Zuletzt aktualisiert: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}
