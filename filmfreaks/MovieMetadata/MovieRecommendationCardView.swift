//
//  MovieRecommendationCardView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieRecommendationCardView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let title: String
    let yearText: String?
    let ratingText: String?
    let posterURL: URL?
    let backdropURL: URL?
    let membershipState: MovieMetadataMembershipState
    var showsMembershipBadge: Bool = true
    let isCurrent: Bool
    let onOpenDetail: () -> Void
    let onAddToBacklog: (() -> Void)?

    private let cardWidth: CGFloat = 148
    private let posterHeight: CGFloat = 204

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpenDetail) {
                poster
                    .frame(width: cardWidth, height: posterHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .topLeading) {
                        if showsMembershipBadge {
                            MovieMembershipBadgeView(state: membershipState)
                                .padding(8)
                        }
                    }
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let yearText {
                    Text(yearText)
                }

                if let ratingText {
                    Label(ratingText, systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let onAddToBacklog, membershipState == .missing {
                Button(action: onAddToBacklog) {
                    Label("Backlog", systemImage: "tray.full.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(displaySettings.tint(0.14))
                        .foregroundStyle(.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: cardWidth + 20, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var poster: some View {
        if let posterURL {
            CachedAsyncImage(
                url: posterURL,
                transaction: Transaction(animation: .easeOut(duration: 0.25))
            ) { phase in
                switch phase {
                case .empty:
                    posterPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                case .failure:
                    backdropFallback
                @unknown default:
                    posterPlaceholder
                }
            }
        } else {
            backdropFallback
        }
    }

    @ViewBuilder
    private var backdropFallback: some View {
        if let backdropURL {
            CachedAsyncImage(url: backdropURL) { phase in
                switch phase {
                case .empty:
                    posterPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                case .failure:
                    posterPlaceholder
                @unknown default:
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.gray.opacity(0.16))
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}
