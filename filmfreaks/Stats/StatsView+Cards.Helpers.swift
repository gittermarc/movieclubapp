//
//  StatsView+Cards.Helpers.swift
//  filmfreaks
//
//  Shared helpers for the Stats dashboard cards.
//

internal import SwiftUI

extension StatsView {

    // MARK: - Stable-ID bridging helpers

    /// Display names of all members in the current group.
    /// (Names are UI only; identity is handled via UUIDs elsewhere.)
    var memberNames: [String] {
        userStore.users
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Display names of reviewers that have at least one rating in the current filter.
    /// Uses stable reviewerId where possible; falls back to canonical name keys.
    var activeReviewerNamesSet: Set<String> {
        func canon(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        var result: Set<String> = []
        for key in activeReviewerKeysSet {
            if key.hasPrefix("id:") {
                let idStr = String(key.dropFirst(3))
                if let uuid = UUID(uuidString: idStr), let u = userStore.users.first(where: { $0.id == uuid }) {
                    let name = u.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { result.insert(name) }
                }
                continue
            }
            if key.hasPrefix("name:") {
                let nameKey = String(key.dropFirst(5))
                if let u = userStore.users.first(where: { canon($0.name) == nameKey }) {
                    let name = u.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { result.insert(name) }
                } else if !nameKey.isEmpty {
                    result.insert(nameKey)
                }
                continue
            }
        }
        return result
    }

    // MARK: - Leaderboard Rows

    @ViewBuilder
    func genreLeaderboardRow(
        rank: Int,
        genre: String,
        count: Int,
        totalMovies: Int,
        maxCount: Int
    ) -> some View {
        let share = Double(count) / Double(max(totalMovies, 1))
        let impact = Double(count) / Double(max(maxCount, 1))

        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(genre)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(count) · \(Int((share * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.quaternarySystemFill))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.35))
                            .frame(width: geo.size.width * impact)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    func actorLeaderboardRow(
        rank: Int,
        entry: ActorEntry,
        totalMovies: Int,
        maxCount: Int
    ) -> some View {
        let share = Double(entry.count) / Double(max(totalMovies, 1))
        let impact = Double(entry.count) / Double(max(maxCount, 1))
        let pop = popularityStore.popularityValue(for: entry.personId)

        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        if pop > 0 {
                            Text("🔥 \(Int(pop.rounded()))")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text("\(entry.count) · \(Int((share * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.quaternarySystemFill))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.35))
                            .frame(width: geo.size.width * impact)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
