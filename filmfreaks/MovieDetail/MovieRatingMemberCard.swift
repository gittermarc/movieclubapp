//
//  MovieRatingMemberCard.swift
//  filmfreaks
//
//  Readable full-detail card for one member rating.
//

internal import SwiftUI

struct MovieRatingMemberCard: View {
    let rating: Rating
    let member: User?
    let groupId: String?
    let isCurrentUser: Bool
    let tintColor: Color

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            reviewerHeader
            fazitPanel
            criteriaProfile

            if let comment {
                Text("„\(comment)“")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
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

    private var criteriaProfile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kriterienprofil")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(RatingCriterion.allCases) { criterion in
                    criterionScoreTile(for: criterion)
                }
            }
        }
    }

    private func criterionScoreTile(for criterion: RatingCriterion) -> some View {
        let score = rating.scores[criterion] ?? 0

        return VStack(alignment: .leading, spacing: 7) {
            Text(criterion.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= score ? tintColor : Color.secondary.opacity(0.14))
                        .frame(width: 16, height: 4)
                }

                Spacer(minLength: 2)

                Text(score == 0 ? "–" : "\(score)/3")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(score == 0 ? Color.secondary : Color.primary)
            }

            Text(score == 0 ? "Nicht bewertet" : "Bewertet")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tintColor.opacity(score == 0 ? 0.045 : 0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var comment: String? {
        let trimmedComment = (rating.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedComment.isEmpty ? nil : trimmedComment
    }
}
