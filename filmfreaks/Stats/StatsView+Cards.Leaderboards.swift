//
//  StatsView+Cards.Leaderboards.swift
//  filmfreaks
//
//  Leaderboard-style cards for StatsView.
//

internal import SwiftUI

extension StatsView {

    var genresCard: some View {
        StatsDashboardCard(title: "Genres", systemImage: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 10) {
                if genresDisplaySource.isEmpty {
                    Text("Keine Genres im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let totalMovies = max(filteredMovies.count, 1)
                    let top = Array(genresDisplaySource.prefix(9))
                    let rest = Array(genresDisplaySource.dropFirst(9))
                    let maxCount = max(top.map(\.count).max() ?? 1, 1)

                    Text("Eure Top-Genres")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.genre) { index, entry in
                            Button {
                                genreChipTapped(entry.genre)
                            } label: {
                                genreLeaderboardRow(
                                    rank: index + 1,
                                    genre: entry.genre,
                                    count: entry.count,
                                    totalMovies: totalMovies,
                                    maxCount: maxCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if !rest.isEmpty {
                        DisclosureGroup("Mehr anzeigen (\(rest.count))") {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 95), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(rest.prefix(24), id: \.genre) { entry in
                                    Button {
                                        genreChipTapped(entry.genre)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.genre)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Text("\(entry.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transaction { $0.animation = nil }
                            .padding(.top, 6)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Text("Tippe ein Genre, um die passenden Filme im Zeitraum zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var actorsCard: some View {
        StatsDashboardCard(title: "Darsteller", systemImage: "person.2.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if actorsByCountRaw.isEmpty {
                    Text("Keine Cast-Daten im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let actorSource = actorsDisplaySource
                    let totalMovies = max(filteredMovies.count, 1)
                    let top = Array(actorSource.prefix(9))
                    let rest = Array(actorSource.dropFirst(9))
                    let maxCount = max(top.map(\.count).max() ?? 1, 1)

                    let totalLimit = showAllActors ? expandedActorsCount : collapsedActorsCount
                    let restLimit = max(0, totalLimit - top.count)
                    let displayedRest = Array(rest.prefix(restLimit))

                    Text("Eure Top-Stars")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                            Button {
                                actorChipTapped(entry)
                            } label: {
                                actorLeaderboardRow(
                                    rank: index + 1,
                                    entry: entry,
                                    totalMovies: totalMovies,
                                    maxCount: maxCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if !rest.isEmpty {
                        DisclosureGroup("Mehr anzeigen (\(rest.count))", isExpanded: $actorsDisclosureExpanded) {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(displayedRest) { entry in
                                    Button {
                                        actorChipTapped(entry)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.name)
                                                .font(.caption)
                                                .lineLimit(1)

                                            Text("\(entry.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transaction { $0.animation = nil }
                            .padding(.top, 6)

                            if rest.count > restLimit {
                                Button {
                                    showAllActors.toggle()
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(showAllActors ? "Weniger anzeigen" : "Noch mehr anzeigen")
                                            .font(.footnote.weight(.semibold))

                                        Image(systemName: showAllActors ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Text("Tippe einen Darsteller, um Details & passende Filme zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var locationsCard: some View {
        StatsDashboardCard(title: "Orte", systemImage: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 10) {
                if moviesByLocation.isEmpty {
                    Text("Keine Filme im ausgewählten Zeitraum.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let totalMovies = max(filteredMovies.count, 1)
                    let top = Array(moviesByLocation.prefix(9))
                    let rest = Array(moviesByLocation.dropFirst(9))
                    let maxCount = max(top.map(\.count).max() ?? 1, 1)

                    Text("Eure Top-Orte")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.location) { index, entry in
                            Button {
                                selectedDrilldown = .location(entry.location)
                            } label: {
                                // Re-use the same leaderboard design as Genres.
                                genreLeaderboardRow(
                                    rank: index + 1,
                                    genre: entry.location,
                                    count: entry.count,
                                    totalMovies: totalMovies,
                                    maxCount: maxCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if !rest.isEmpty {
                        DisclosureGroup("Mehr anzeigen (\(rest.count))") {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(rest.prefix(24), id: \.location) { entry in
                                    Button {
                                        selectedDrilldown = .location(entry.location)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.location)
                                                .font(.caption)
                                                .lineLimit(1)

                                            Text("\(entry.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transaction { $0.animation = nil }
                            .padding(.top, 6)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Text("Tippe einen Ort, um die passenden Filme im Zeitraum zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var suggestionsCard: some View {
        StatsDashboardCard(title: "Vorgeschlagen von", systemImage: "person.fill.questionmark") {
            VStack(alignment: .leading, spacing: 10) {
                if suggestionsByUser.isEmpty {
                    Text("Keine Vorschläge im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let totalMovies = max(filteredMovies.count, 1)
                    let top = Array(suggestionsByUser.prefix(9))
                    let rest = Array(suggestionsByUser.dropFirst(9))
                    let maxCount = max(top.map(\.count).max() ?? 1, 1)

                    Text("Eure Top-Empfehler")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.name) { index, entry in
                            Button {
                                selectedDrilldown = .suggestedBy(entry.name)
                            } label: {
                                // Same leaderboard look as Genres.
                                genreLeaderboardRow(
                                    rank: index + 1,
                                    genre: entry.name,
                                    count: entry.count,
                                    totalMovies: totalMovies,
                                    maxCount: maxCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if !rest.isEmpty {
                        DisclosureGroup("Mehr anzeigen (\(rest.count))") {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(rest.prefix(24), id: \.name) { entry in
                                    Button {
                                        selectedDrilldown = .suggestedBy(entry.name)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.name)
                                                .font(.caption)
                                                .lineLimit(1)

                                            Text("\(entry.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transaction { $0.animation = nil }
                            .padding(.top, 6)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Text("Tippe eine Person, um ihre vorgeschlagenen Filme zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
