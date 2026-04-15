//
//  StatsView+Cards.TasteDynamics.swift
//  filmfreaks
//
//  Social taste and group-dynamics card for StatsView.
//

internal import SwiftUI

extension StatsView {

    var tasteDynamicsCard: some View {
        StatsDashboardCard(title: "Geschmack & Dynamik", systemImage: "person.2.wave.2.fill") {
            VStack(alignment: .leading, spacing: 14) {
                if tasteTwins == nil,
                   frictionPair == nil,
                   strictestReviewer == nil,
                   mostGenerousReviewer == nil,
                   hotTakeReviewer == nil {
                    Text("Noch nicht genug gemeinsame Bewertungen für belastbare Gruppen-Dynamik im aktuellen Filter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Diese Insights vergleichen nur gemeinsame Bewertungen und blenden dünne Datenlagen aus.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let tasteTwins {
                        tastePairInsightRow(
                            title: "Geschmackszwillinge",
                            subtitle: "\(tasteTwins.firstReviewerName) & \(tasteTwins.secondReviewerName)",
                            detail: "Ø Abweichung \(String(format: "%.1f", tasteTwins.averageDifference)) bei \(tasteTwins.sharedMoviesCount) gemeinsamen Filmen",
                            systemImage: "person.2.fill",
                            badgeText: "nah dran",
                            badgeBackground: Color.green.opacity(0.15)
                        )
                    }

                    if let frictionPair {
                        tastePairInsightRow(
                            title: "Reibungspaar",
                            subtitle: "\(frictionPair.firstReviewerName) & \(frictionPair.secondReviewerName)",
                            detail: "Ø Abstand \(String(format: "%.1f", frictionPair.averageDifference)) bei \(frictionPair.sharedMoviesCount) gemeinsamen Filmen",
                            systemImage: "bolt.horizontal.fill",
                            badgeText: "diskutiert gern",
                            badgeBackground: Color.orange.opacity(0.15)
                        )
                    }

                    if strictestReviewer != nil || mostGenerousReviewer != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bewertungsstil")
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 10) {
                                if let strictestReviewer {
                                    reviewerBiasTile(
                                        title: "Strengster Bewerter",
                                        reviewerName: strictestReviewer.reviewerName,
                                        biasText: String(format: "%.1f unter Gruppe", abs(strictestReviewer.averageBias)),
                                        comparisonsText: "\(strictestReviewer.comparableRatingsCount) Vergleiche",
                                        systemImage: "arrow.down.circle.fill",
                                        badgeBackground: Color.red.opacity(0.15)
                                    )
                                }

                                if let mostGenerousReviewer {
                                    reviewerBiasTile(
                                        title: "Großzügigster Bewerter",
                                        reviewerName: mostGenerousReviewer.reviewerName,
                                        biasText: String(format: "%.1f über Gruppe", mostGenerousReviewer.averageBias),
                                        comparisonsText: "\(mostGenerousReviewer.comparableRatingsCount) Vergleiche",
                                        systemImage: "arrow.up.circle.fill",
                                        badgeBackground: Color.green.opacity(0.15)
                                    )
                                }
                            }
                        }
                    }

                    if let hotTakeReviewer {
                        tastePairInsightRow(
                            title: "Hot-Take-Indikator",
                            subtitle: hotTakeReviewer.reviewerName,
                            detail: "\(hotTakeReviewer.hotTakeCount) deutliche Ausreißer bei \(hotTakeReviewer.comparableRatingsCount) Vergleichen • Quote \(Int((hotTakeReviewer.hotTakeRate * 100).rounded()))%",
                            systemImage: "flame.fill",
                            badgeText: String(format: "Ø %.1f Abstand", hotTakeReviewer.averageAbsoluteDeviation),
                            badgeBackground: Color.purple.opacity(0.15)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    func tastePairInsightRow(
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

    @ViewBuilder
    func reviewerBiasTile(
        title: String,
        reviewerName: String,
        biasText: String,
        comparisonsText: String,
        systemImage: String,
        badgeBackground: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(reviewerName)
                .font(.headline)
                .lineLimit(2)

            Text(biasText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(comparisonsText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemBackground))
        )
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10)
                .fill(badgeBackground)
                .frame(width: 10, height: 10)
                .padding(12)
        }
    }
}
