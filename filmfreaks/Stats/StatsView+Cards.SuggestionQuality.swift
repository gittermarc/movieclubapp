//
//  StatsView+Cards.SuggestionQuality.swift
//  filmfreaks
//
//  Suggestion quality cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var suggestionQualityCard: some View {
        StatsDashboardCard(title: "Vorschläge mit Wirkung", systemImage: "hand.thumbsup.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if bestAverageRatingSuggester == nil,
                   bestHitRateSuggester == nil,
                   mostControversialSuggester == nil,
                   fastestToWatchSuggester == nil {
                    Text("Noch nicht genug belastbare Vorschlagsdaten für Qualitäts-Insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Hier zählen nicht nur Mengen, sondern Treffer, Konsens und wie schnell ein Vorschlag wirklich geschaut wird.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let bestAverageRatingSuggester {
                        suggestionQualityRow(
                            title: "Bestbewertete Vorschläge",
                            subtitle: bestAverageRatingSuggester.suggesterName,
                            detail: "\(bestAverageRatingSuggester.ratedSuggestionsCount) bewertete Vorschläge • Gruppen-Ø \(String(format: "%.1f", bestAverageRatingSuggester.averageGroupRating))",
                            badgeText: String(format: "Ø %.1f", bestAverageRatingSuggester.averageGroupRating),
                            badgeBackground: Color.green.opacity(0.15),
                            systemImage: "star.fill"
                        )
                    }

                    if let bestHitRateSuggester {
                        suggestionQualityRow(
                            title: "Höchste Trefferquote",
                            subtitle: bestHitRateSuggester.suggesterName,
                            detail: "\(bestHitRateSuggester.crowdPleaserCount) Crowdpleaser aus \(bestHitRateSuggester.ratedSuggestionsCount) bewerteten Vorschlägen",
                            badgeText: percentText(bestHitRateSuggester.crowdPleaserRate),
                            badgeBackground: Color.blue.opacity(0.15),
                            systemImage: "target"
                        )
                    }

                    if let mostControversialSuggester {
                        suggestionQualityRow(
                            title: "Meiste Gesprächsstoff-Picks",
                            subtitle: mostControversialSuggester.suggesterName,
                            detail: "\(mostControversialSuggester.controversialCount) kontroverse Vorschläge aus \(mostControversialSuggester.ratedSuggestionsCount) bewerteten Picks",
                            badgeText: percentText(mostControversialSuggester.controversialRate),
                            badgeBackground: Color.orange.opacity(0.15),
                            systemImage: "bubble.left.and.exclamationmark.bubble.right.fill"
                        )
                    }

                    if let fastestToWatchSuggester {
                        suggestionQualityRow(
                            title: "Schnell auf dem Bildschirm",
                            subtitle: fastestToWatchSuggester.suggesterName,
                            detail: "\(fastestToWatchSuggester.datedSuggestionsCount) datierte Vorschläge • \(fastestToWatchRatingContext(fastestToWatchSuggester))",
                            badgeText: daysText(fastestToWatchSuggester.averageDaysToWatch),
                            badgeBackground: Color.purple.opacity(0.15),
                            systemImage: "calendar.badge.clock"
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func suggestionQualityRow(
        title: String,
        subtitle: String,
        detail: String,
        badgeText: String,
        badgeBackground: Color,
        systemImage: String
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
                        .monospacedDigit()
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

    private func percentText(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100.0)
    }

    private func daysText(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 1 {
            return "1 Tag"
        }
        return "\(rounded) Tage"
    }

    private func fastestToWatchRatingContext(_ insight: StatsSuggestionWatchTimingInsight) -> String {
        let label: String
        switch insight.ratingDisplayMode {
        case .ratingAverage:
            label = "Kriterien-Ø"
        case .fazitAverage:
            label = "Gruppen-Ø"
        }

        return "\(label) \(String(format: "%.1f", insight.averageGroupRating)) bei \(insight.ratedSuggestionsCount) bewerteten Vorschlägen"
    }
}
