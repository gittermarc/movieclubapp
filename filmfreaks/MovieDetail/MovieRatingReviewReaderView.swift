//
//  MovieRatingReviewReaderView.swift
//  filmfreaks
//
//  Focused, editorial reading view for a complete member review.
//

internal import SwiftUI

struct MovieRatingReviewReaderView: View {
    let movie: Movie
    let rating: Rating
    let comment: String
    let member: User?
    let groupId: String?
    let isCurrentUser: Bool
    let tintColor: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filmContext
                    authorContext
                    reviewText
                    criteriaProfile
                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle("Rezension")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filmContext: some View {
        HStack(alignment: .top, spacing: 14) {
            MovieRatingPosterThumbnailView(
                movie: movie,
                width: 78,
                height: 116,
                cornerRadius: 14
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(movie.year)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        ratingChip
                        fazitChip
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ratingChip
                        fazitChip
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tintColor.opacity(0.16), lineWidth: 1)
        }
    }

    private var authorContext: some View {
        HStack(alignment: .center, spacing: 12) {
            MemberAvatarView(
                member: member,
                fallbackName: rating.reviewerName,
                groupId: groupId,
                size: 48,
                tintColor: tintColor
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(rating.reviewerName)
                        .font(.headline.weight(.bold))

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
                    Text("Aktualisiert \(updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Mitgliedsrezension")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var reviewText: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "quote.opening")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tintColor)
                    .frame(width: 34, height: 34)
                    .background(tintColor.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rezension")
                        .font(.headline.weight(.bold))

                    Text("Persönlicher Eindruck von \(rating.reviewerName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(comment)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(7)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tintColor.opacity(0.20), lineWidth: 1)
        }
    }

    private var criteriaProfile: some View {
        MovieRatingCriteriaProfileView(
            rating: rating,
            tintColor: tintColor
        )
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var ratingChip: some View {
        metricChip(
            title: "Kriterien",
            value: String(format: "%.1f / 10", rating.averageScoreNormalizedTo10),
            color: tintColor
        )
    }

    private var fazitChip: some View {
        metricChip(
            title: "Fazit",
            value: MovieRatingFazitScale.scoreText(rating.fazitScore),
            color: MovieRatingFazitScale.color(for: rating.fazitScore)
        )
    }

    private func metricChip(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(.secondary)

            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.11), in: Capsule())
    }
}
