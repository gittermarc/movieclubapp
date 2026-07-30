//
//  MovieRatingsGroupSummaryCard.swift
//  filmfreaks
//
//  Group-level overview for the ratings sheet.
//

internal import SwiftUI

struct MovieRatingsGroupSummaryCard: View {
    let summary: MovieRatingGroupSummary
    let tintColor: Color

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label("Gruppenwertung", systemImage: "person.3.fill")
                    .font(.subheadline.weight(.bold))

                Spacer(minLength: 8)

                Text("\(summary.ratingsCount) \(summary.ratingsCount == 1 ? "Stimme" : "Stimmen")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                metric(
                    title: "Kriterien Ø",
                    value: averageText(summary.averageRating),
                    icon: "slider.horizontal.3",
                    color: tintColor
                )

                metric(
                    title: "Fazit Ø",
                    value: averageText(summary.averageFazit),
                    icon: "sparkles",
                    color: MovieRatingFazitScale.color(for: roundedFazit)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Kriterienprofil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(RatingCriterion.allCases) { criterion in
                        criterionMetric(for: criterion)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tintColor.opacity(0.18), lineWidth: 1)
        }
    }

    private var roundedFazit: Int? {
        summary.averageFazit.map { Int($0.rounded()) }
    }

    private func metric(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.bold))
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func criterionMetric(for criterion: RatingCriterion) -> some View {
        let average = summary.criterionAverages[criterion]
        let count = summary.criterionRatingsCounts[criterion] ?? 0

        return HStack(spacing: 6) {
            Text(criterion.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let average {
                Text(String(format: "%.1f/3", average))
                    .font(.caption2.weight(.bold))
            } else {
                Text("–")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tintColor.opacity(0.08), in: Capsule())
    }

    private func averageText(_ value: Double?) -> String {
        guard let value else {
            return "–"
        }

        return String(format: "%.1f / 10", value)
    }
}
