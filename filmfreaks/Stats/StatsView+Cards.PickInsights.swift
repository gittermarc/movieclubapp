//
//  StatsView+Cards.PickInsights.swift
//  filmfreaks
//
//  Recommendation cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var pickInsightsCard: some View {
        StatsDashboardCard(title: "Nächster Filmabend", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                if safePick == nil, daringPick == nil, crowdPleaser == nil {
                    Text("Noch nicht genug belastbare Bewertungen für Auswahl-Insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Keine doppelte Topliste: Hier zählen Bewertung, Konsens und Polarisierung gemeinsam.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let safePick {
                        pickInsightRow(
                            title: "Safe Pick",
                            subtitle: "Stark bewertet, wenig Streit",
                            insight: safePick,
                            badgeText: "Sicher",
                            badgeBackground: Color.green.opacity(0.15)
                        )
                    }

                    if let daringPick {
                        pickInsightRow(
                            title: "Mutiger Pick",
                            subtitle: "Polarisiert, aber spannend",
                            insight: daringPick,
                            badgeText: "Mutig",
                            badgeBackground: Color.orange.opacity(0.15)
                        )
                    }

                    if let crowdPleaser {
                        pickInsightRow(
                            title: "Crowdpleaser",
                            subtitle: "Breit getragen in der Gruppe",
                            insight: crowdPleaser,
                            badgeText: "Gruppe",
                            badgeBackground: Color.blue.opacity(0.15)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pickInsightRow(
        title: String,
        subtitle: String,
        insight: StatsPickInsight,
        badgeText: String,
        badgeBackground: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(badgeBackground)
                    .clipShape(Capsule())
            }

            movieRow(
                insight.movie,
                trailingText: String(format: "%.1f", insight.averageRating),
                trailingBackground: displaySettings.tintSoftBackground
            )

            HStack(spacing: 8) {
                pickMetricChip(
                    text: String(format: "Ø %.1f", insight.averageRating),
                    background: displaySettings.tintSoftBackground
                )

                pickMetricChip(
                    text: "\(insight.ratingsCount) Bewertungen",
                    background: Color.gray.opacity(0.12)
                )

                pickMetricChip(
                    text: String(format: "±%.1f", insight.standardDeviation),
                    background: Color.gray.opacity(0.12)
                )
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func pickMetricChip(text: String, background: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(Capsule())
    }
}
