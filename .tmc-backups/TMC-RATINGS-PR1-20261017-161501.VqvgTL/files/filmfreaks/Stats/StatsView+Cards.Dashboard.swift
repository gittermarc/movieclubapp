//
//  StatsView+Cards.Dashboard.swift
//  filmfreaks
//
//  Dashboard cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var heroCard: some View {
        StatsDashboardCard(title: "Dashboard", systemImage: "rectangle.3.group") {
            VStack(alignment: .leading, spacing: 10) {

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(heroTitle)
                            .font(.title3.bold())
                            .lineLimit(2)

                        Text(heroSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Ø")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(overallAverageRating != nil ? String(format: "%.1f", overallAverageRating!) : "–")
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 10) {
                    Label("\(filteredMovies.count) Filme", systemImage: "film")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    Label("\(activeReviewersCount) aktiv", systemImage: "person.2.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    if let date = mostRecentWatchedDate {
                        Label(Self.recentDateFormatter.string(from: date), systemImage: "clock")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    var kpiRow: some View {
        StatsDashboardCard(title: "KPIs", systemImage: "speedometer") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StatsKPICard(
                        title: "Filme",
                        value: "\(filteredMovies.count)",
                        subtitle: "im Zeitraum",
                        systemImage: "film"
                    )

                    StatsKPICard(
                        title: "Ø Bewertung",
                        value: overallAverageRating != nil ? String(format: "%.1f", overallAverageRating!) : "–",
                        subtitle: "0–10 Skala",
                        systemImage: "star.fill"
                    )

                    StatsKPICard(
                        title: "Bewertungen",
                        value: "\(totalRatingsCount)",
                        subtitle: "alle Nutzer",
                        systemImage: "text.bubble.fill"
                    )

                    StatsKPICard(
                        title: "Aktive",
                        value: "\(activeReviewersCount)",
                        subtitle: "haben bewertet",
                        systemImage: "person.2.fill"
                    )

                    StatsKPICard(
                        title: "Coverage",
                        value: "\(ratedMoviesCount)/\(max(1, filteredMovies.count))",
                        subtitle: ratingCoveragePercentText,
                        systemImage: "checkmark.seal.fill"
                    )
                }
                .padding(.vertical, 2)
            }
        }
    }
}
