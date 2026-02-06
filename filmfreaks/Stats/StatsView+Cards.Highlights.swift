//
//  StatsView+Cards.Highlights.swift
//  filmfreaks
//
//  Highlights cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var highlightsCard: some View {
        StatsDashboardCard(title: "Highlights", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top bewertet")
                        .font(.subheadline.weight(.semibold))

                    if topRatedHighlights.isEmpty {
                        Text("Noch keine Bewertungen im ausgewählten Zeitraum.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(topRatedHighlights) { entry in
                            movieRow(entry.movie, trailingText: String(format: "%.1f", entry.value))
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Kontrovers")
                        .font(.subheadline.weight(.semibold))

                    Text("Je höher, desto mehr gehen eure Meinungen auseinander (Standardabweichung).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if controversialHighlights.isEmpty {
                        Text("Dafür braucht es mindestens 2 Bewertungen pro Film.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controversialHighlights) { entry in
                            movieRow(entry.movie, trailingText: String(format: "±%.1f", entry.value), trailingBackground: Color.orange.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    var criticsCard: some View {
        StatsDashboardCard(title: "Kritik vs TMDB", systemImage: "theatermasks") {
            VStack(alignment: .leading, spacing: 14) {

                if criticGapEntries.isEmpty {
                    Text("Für diesen Bereich brauchen Filme sowohl eine TMDB-Bewertung als auch mindestens eine Gruppenbewertung im aktuellen Filter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Je größer der Abstand, desto mehr weicht eure Gruppenmeinung vom TMDB-Score ab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Underrated bei TMDB")
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 0)

                            if criticGapGroupHigher.count > 3 {
                                Button("Alle") {
                                    selectedDrilldown = .critics(.groupHigher)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text("Eure Gruppe bewertet höher als TMDB")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if criticGapGroupHigher.isEmpty {
                            Text("Keine klaren Abweichungen im aktuellen Filter.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(criticGapGroupHigher.prefix(3)) { entry in
                                criticGapRow(entry, kind: .groupHigher)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overrated bei TMDB")
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 0)

                            if criticGapGroupLower.count > 3 {
                                Button("Alle") {
                                    selectedDrilldown = .critics(.groupLower)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text("TMDB bewertet höher als eure Gruppe")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if criticGapGroupLower.isEmpty {
                            Text("Keine klaren Abweichungen im aktuellen Filter.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(criticGapGroupLower.prefix(3)) { entry in
                                criticGapRow(entry, kind: .groupLower)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            selectedDrilldown = .critics(.groupHigher)
                        } label: {
                            Label("Underrated", systemImage: "arrow.up.right")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedDrilldown = .critics(.groupLower)
                        } label: {
                            Label("Overrated", systemImage: "arrow.down.right")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}
