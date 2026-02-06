//
//  StatsView+Cards.Ratings.swift
//  filmfreaks
//
//  Ratings-related cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var ratingsPerPersonCard: some View {
        StatsDashboardCard(title: "Bewertungen pro Person", systemImage: "person.3.sequence.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if userStore.users.isEmpty {
                    Text("Noch keine Mitglieder in der Filmgruppe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let totalMovies = filteredMovies.count
                    let denom = max(1, totalMovies)

                    VStack(alignment: .leading, spacing: 10) {

                        HStack(spacing: 8) {
                            if totalMovies == 0 {
                                Text("Im aktuellen Filter gibt es keine Filme.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Bezogen auf \(totalMovies) Filme im aktuellen Filter.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            if !activeReviewerNamesSet.isEmpty {
                                Text("\(activeReviewerNamesSet.count) aktiv")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(userStore.users) { user in
                                let stats = statsForUser(user)
                                let progress = Double(stats.movieCount) / Double(denom)
                                let missing = max(0, totalMovies - stats.movieCount)

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack(spacing: 6) {
                                                Text("\(stats.movieCount)/\(totalMovies) Filme")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)

                                                Text("• \(stats.ratingsCount) Bewertungen")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)

                                                if missing > 0 && totalMovies > 0 {
                                                    Text("• \(missing) fehlen")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        Spacer(minLength: 0)

                                        if let avg = stats.averageRating {
                                            Text(String(format: "%.1f", avg))
                                                .font(.headline)
                                                .monospacedDigit()
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(displaySettings.tintSoftBackground)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        } else {
                                            Text("–")
                                                .font(.headline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    ProgressView(value: progress)
                                        .tint(displaySettings.tintColor)

                                    HStack {
                                        Text("Coverage: \(String(format: "%.0f", progress * 100))%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer(minLength: 0)

                                        if totalMovies > 0 && stats.movieCount == totalMovies {
                                            Text("Komplett")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(Color.green.opacity(0.15))
                                                .clipShape(Capsule())
                                        } else if stats.ratingsCount == 0 {
                                            Text("Noch nichts bewertet")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(Color.orange.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
