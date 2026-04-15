//
//  StatsView+Cards.RatingDimensions.swift
//  filmfreaks
//
//  Rating-dimension cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var ratingDimensionsCard: some View {
        StatsDashboardCard(title: "Bewertungskriterien", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                if strongestCriterion == nil,
                   weakestCriterion == nil,
                   mostControversialCriterion == nil,
                   criterionReviewerHighlight == nil {
                    Text("Noch nicht genug Kriterien-Bewertungen für belastbare Insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if let strongestCriterion {
                        criterionInsightRow(
                            title: "Stärkstes Kriterium",
                            subtitle: strongestCriterion.criterion.rawValue,
                            detail: "\(strongestCriterion.ratingsCount) Einzelwertungen • Gruppen-Ø \(criterionAverageText(strongestCriterion.averageScore))",
                            systemImage: "star.fill",
                            badgeText: criterionAverageText(strongestCriterion.averageScore),
                            badgeBackground: Color.green.opacity(0.15)
                        )
                    }

                    if let weakestCriterion {
                        criterionInsightRow(
                            title: "Schwächstes Kriterium",
                            subtitle: weakestCriterion.criterion.rawValue,
                            detail: "\(weakestCriterion.ratingsCount) Einzelwertungen • Gruppen-Ø \(criterionAverageText(weakestCriterion.averageScore))",
                            systemImage: "arrow.down.circle.fill",
                            badgeText: criterionAverageText(weakestCriterion.averageScore),
                            badgeBackground: Color.orange.opacity(0.15)
                        )
                    }

                    if let mostControversialCriterion {
                        criterionInsightRow(
                            title: "Kontroversestes Kriterium",
                            subtitle: mostControversialCriterion.criterion.rawValue,
                            detail: "\(mostControversialCriterion.ratingsCount) Einzelwertungen • Streuung \(String(format: "%.2f", mostControversialCriterion.standardDeviation))",
                            systemImage: "waveform.path.ecg",
                            badgeText: mostControversialCriterion.isMeaningfullyControversial ? "umstritten" : "ruhig",
                            badgeBackground: mostControversialCriterion.isMeaningfullyControversial ? Color.purple.opacity(0.15) : Color.gray.opacity(0.12)
                        )
                    }

                    if let criterionReviewerHighlight {
                        criterionInsightRow(
                            title: "Persönlicher Schwerpunkt",
                            subtitle: "\(criterionReviewerHighlight.reviewerName) feiert \(criterionReviewerHighlight.criterion.rawValue)",
                            detail: "\(criterionReviewerHighlight.ratingsCount) Wertungen • Person \(criterionAverageText(criterionReviewerHighlight.reviewerAverageScore)) vs Gruppe \(criterionAverageText(criterionReviewerHighlight.groupAverageScore))",
                            systemImage: "person.crop.circle.badge.plus",
                            badgeText: "+\(String(format: "%.2f", criterionReviewerHighlight.averageDelta))",
                            badgeBackground: Color.blue.opacity(0.15)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    func criterionInsightRow(
        title: String,
        subtitle: String,
        detail: String,
        systemImage: String,
        badgeText: String,
        badgeBackground: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))

                        Text(subtitle)
                            .font(.subheadline)
                    }

                    Spacer(minLength: 0)

                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    func criterionAverageText(_ value: Double) -> String {
        String(format: "%.2f/3", value)
    }
}
