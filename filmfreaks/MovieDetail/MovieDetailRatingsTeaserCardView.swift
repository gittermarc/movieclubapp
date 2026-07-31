//
//  MovieDetailRatingsTeaserCardView.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailRatingsTeaserCardView: View {
    let averageRating: Double?
    let averageFazit: Double?
    let ratingsCount: Int
    let selectedUser: User?
    let members: [User]
    let groupId: String?
    let hasPendingChanges: Bool
    let ratingsPreview: [Rating]
    let tintSoftBackground: Color
    let onTap: () -> Void

    private var ratingsCountText: String {
        "\(ratingsCount) \(ratingsCount == 1 ? "Bewertung" : "Bewertungen")"
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            MovieDetailSectionCard(title: "Bewertungen") {
                VStack(alignment: .leading, spacing: 10) {

                    HStack(spacing: 8) {
                        if let avg = averageRating {
                            Text(String(format: "Ø %.1f / 10", avg))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tintSoftBackground)
                                .clipShape(Capsule())
                        } else {
                            Text("Noch keine Bewertungen")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let f = averageFazit {
                            let fazitColor = MovieRatingFazitScale.color(for: Int(f.rounded()))

                            Text(String(format: "Fazit Ø %.1f", f))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(fazitColor)
                                .background(fazitColor.opacity(0.14))
                                .clipShape(Capsule())
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.secondary)

                        Text(ratingsCountText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        if let selectedUser {
                            MemberAvatarView(
                                member: selectedUser,
                                groupId: groupId,
                                size: 22
                            )

                            Text("Als: \(selectedUser.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if hasPendingChanges {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Ungespeicherte Änderungen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !ratingsPreview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(ratingsPreview) { rating in
                                HStack(spacing: 10) {
                                    MemberAvatarView(
                                        member: MemberAvatarResolver.member(for: rating, in: members),
                                        fallbackName: rating.reviewerName,
                                        groupId: groupId,
                                        size: 28
                                    )

                                    Text(rating.reviewerName)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)

                                    Spacer(minLength: 0)

                                    Text(String(format: "%.1f / 10", rating.averageScoreNormalizedTo10))
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    } else {
                        Text("Tippe hier, um eine Bewertung abzugeben.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MovieDetailRatingsTeaserCardView(
        averageRating: 7.8,
        averageFazit: 8.2,
        ratingsCount: 2,
        selectedUser: sampleUsers.first,
        members: sampleUsers,
        groupId: "preview-group",
        hasPendingChanges: true,
        ratingsPreview: [
            Rating(reviewerName: "Marc", scores: [.action: 3, .suspense: 2], comment: nil, fazitScore: 9),
            Rating(reviewerName: "Claudia", scores: [.emotion: 3, .music: 2], comment: nil, fazitScore: 8)
        ],
        tintSoftBackground: Color.gray.opacity(0.12),
        onTap: {}
    )
    .padding()
}
