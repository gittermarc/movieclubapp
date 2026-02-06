//
//  StatsView+Cards.HealthAndTrends.swift
//  filmfreaks
//
//  Group Health and Trends cards for StatsView.
//

internal import SwiftUI
internal import Charts

extension StatsView {

    var groupHealthCard: some View {
        StatsDashboardCard(title: "Group Health", systemImage: "heart.text.square") {
            VStack(alignment: .leading, spacing: 12) {

                let members = memberNames
                let membersCount = members.count
                let activeCount = activeReviewersCount
                let unrated = unratedMoviesCount

                HStack(spacing: 10) {
                    Label("\(membersCount) Mitglieder", systemImage: "person.2.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    Label("\(activeCount) aktiv", systemImage: "bolt.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    if unrated > 0 {
                        Label("\(unrated) unbewertet", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aktivität")
                        .font(.subheadline.weight(.semibold))

                    if membersCount == 0 {
                        Text("Keine Mitglieder in der Gruppe.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        let activity = Double(activeCount) / Double(max(1, membersCount))
                        ProgressView(value: activity)
                            .tint(displaySettings.tintColor)

                        Text("\(activeCount) von \(membersCount) Mitgliedern haben im Zeitraum mindestens einmal bewertet (\(String(format: "%.0f", activity * 100))%).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Coverage")
                        .font(.subheadline.weight(.semibold))

                    let cov = Double(ratedMoviesCount) / Double(max(1, filteredMovies.count))
                    ProgressView(value: cov)
                        .tint(displaySettings.tintColor)

                    Text("\(ratedMoviesCount) von \(max(1, filteredMovies.count)) Filmen haben mindestens eine Bewertung (\(String(format: "%.0f", cov * 100))%).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Alle haben bewertet")
                        .font(.subheadline.weight(.semibold))

                    if activeReviewerNamesSet.isEmpty {
                        Text("Noch keine Bewertungen im ausgewählten Zeitraum.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        let allActive = moviesRatedByAllActiveMembersCount
                        let pActive = Double(allActive) / Double(max(1, filteredMovies.count))

                        ProgressView(value: pActive)
                            .tint(displaySettings.tintColor)

                        Text("\(allActive) von \(max(1, filteredMovies.count)) Filmen wurden von allen aktiven Mitgliedern bewertet (\(String(format: "%.0f", pActive * 100))%).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if membersCount > 0 && Set(members).count != activeReviewerNamesSet.count {
                            let allMembers = moviesRatedByAllMembersCount
                            let pMembers = Double(allMembers) / Double(max(1, filteredMovies.count))

                            Text("Strenger gemessen an allen Mitgliedern: \(allMembers) Filme (\(String(format: "%.0f", pMembers * 100))%).")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    var trendsCard: some View {
        StatsDashboardCard(title: "Trends", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 12) {
                if monthTrends.isEmpty {
                    Text("Keine Daten im ausgewählten Zeitraum.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filme pro Monat")
                            .font(.subheadline.weight(.semibold))

                        Chart(monthTrends) { item in
                            BarMark(
                                x: .value("Monat", item.monthStart, unit: .month),
                                y: .value("Filme", item.movieCount)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                            }
                        }
                        .frame(height: 160)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ø Bewertung pro Monat")
                            .font(.subheadline.weight(.semibold))

                        Chart(monthTrends.compactMap { item -> StatsMonthTrend? in
                            guard let avg = item.averageRating else { return nil }
                            return StatsMonthTrend(monthStart: item.monthStart, movieCount: item.movieCount, averageRating: avg)
                        }) { item in
                            LineMark(
                                x: .value("Monat", item.monthStart, unit: .month),
                                y: .value("Ø", item.averageRating ?? 0)
                            )
                            PointMark(
                                x: .value("Monat", item.monthStart, unit: .month),
                                y: .value("Ø", item.averageRating ?? 0)
                            )
                        }
                        .chartYScale(domain: 0...10)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                            }
                        }
                        .frame(height: 160)

                        Text("Tipp: Tippe einen Monat unten an, um die Filme als Liste zu öffnen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(moviesPerMonth, id: \.date) { entry in
                                Button {
                                    selectedDrilldown = .month(entry.date)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(Self.monthFormatter.string(from: entry.date))
                                            .font(.caption)
                                            .lineLimit(1)

                                        Text("\(entry.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}
