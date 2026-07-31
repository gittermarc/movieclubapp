//
//  MovieRatingCriteriaProfileView.swift
//  filmfreaks
//
//  Reusable criteria profile for member cards and the review reader.
//

internal import SwiftUI

struct MovieRatingCriteriaProfileView: View {
    let rating: Rating
    let tintColor: Color

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
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
        .background(
            tintColor.opacity(score == 0 ? 0.045 : 0.09),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
