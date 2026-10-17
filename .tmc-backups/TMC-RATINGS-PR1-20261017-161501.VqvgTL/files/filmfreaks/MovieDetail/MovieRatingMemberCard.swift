//
//  MovieRatingMemberCard.swift
//  filmfreaks
//
//  Compact member rating with a dedicated review preview.
//

internal import SwiftUI

struct MovieRatingMemberCard: View {
    let rating: Rating
    let member: User?
    let groupId: String?
    let isCurrentUser: Bool
    let tintColor: Color
    let reviewTransitionNamespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            reviewerHeader

            if let comment = MovieRatingReviewPresentation.comment(for: rating) {
                MovieRatingReviewExcerptView(
                    ratingID: rating.id,
                    reviewerName: rating.reviewerName,
                    comment: comment,
                    tintColor: tintColor,
                    transitionNamespace: reviewTransitionNamespace
                )
            }

            fazitPanel

            MovieRatingCriteriaProfileView(
                rating: rating,
                tintColor: tintColor
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isCurrentUser ? tintColor.opacity(0.34) : Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var reviewerHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            MemberAvatarView(
                member: member,
                fallbackName: rating.reviewerName,
                groupId: groupId,
                size: 40,
                tintColor: tintColor
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(rating.reviewerName)
                        .font(.subheadline.weight(.bold))

                    if isCurrentUser {
                        Text("Du")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tintColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tintColor.opacity(0.12), in: Capsule())
                    }
                }

                if let updatedAt = rating.updatedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("Aktualisiert")
                        Text(updatedAt, format: .dateTime.day().month(.abbreviated).year())
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(String(format: "%.1f / 10", rating.averageScoreNormalizedTo10))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(tintColor.opacity(0.12), in: Capsule())
        }
    }

    @ViewBuilder
    private var fazitPanel: some View {
        if let fazitScore = rating.fazitScore {
            let color = MovieRatingFazitScale.color(for: fazitScore)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fazit")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(fazitScore) / 10")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)

                Text("Fazit nicht vergeben")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

}
