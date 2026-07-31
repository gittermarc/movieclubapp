//
//  MovieRatingReviewExcerptView.swift
//  filmfreaks
//
//  Compact, tappable preview for a member's full review.
//

internal import SwiftUI

struct MovieRatingReviewExcerptView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let ratingID: UUID
    let reviewerName: String
    let comment: String
    let tintColor: Color
    let transitionNamespace: Namespace.ID

    var body: some View {
        NavigationLink(value: MovieRatingReviewRoute(ratingID: ratingID)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tintColor)
                        .frame(width: 28, height: 28)
                        .background(tintColor.opacity(0.14), in: Circle())

                    Text("Rezension")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tintColor)
                }

                Text(comment)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 8 : 4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 5) {
                    Text("Ganze Rezension lesen")
                        .font(.caption.weight(.bold))

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(tintColor)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tintColor.opacity(0.055))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tintColor.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: ratingID, in: transitionNamespace)
        .accessibilityLabel("Ganze Rezension von \(reviewerName) lesen")
        .accessibilityHint("Öffnet die vollständige Rezension.")
    }
}
