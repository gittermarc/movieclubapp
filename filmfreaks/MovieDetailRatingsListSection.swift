//
//  MovieDetailRatingsListSection.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailRatingsListSection: View {
    let ratings: [Rating]
    @Binding var expandedRatingIds: Set<UUID>

    var body: some View {
        if ratings.isEmpty {
            Text("Noch keine Bewertungen vorhanden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ratings) { rating in
                    ratingSummaryCardCompact(rating)
                }
            }
        }
    }

    private func isExpandedBinding(for rating: Rating) -> Binding<Bool> {
        Binding(
            get: { expandedRatingIds.contains(rating.id) },
            set: { newValue in
                if newValue {
                    expandedRatingIds.insert(rating.id)
                } else {
                    expandedRatingIds.remove(rating.id)
                }
            }
        )
    }

    @ViewBuilder
    private func ratingSummaryCardCompact(_ rating: Rating) -> some View {
        let comment = (rating.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasComment = !comment.isEmpty

        DisclosureGroup(isExpanded: isExpandedBinding(for: rating)) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    // Fazit (separat, 1-10)
                    HStack(spacing: 8) {
                        Text("Fazit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)

                        if let f = rating.fazitScore {
                            Text("Fazit \(f) / 10")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colorForFazit(f).opacity(0.18))
                                .clipShape(Capsule())
                        } else {
                            Text("Fazit –")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    ForEach(RatingCriterion.allCases) { criterion in
                        let score = rating.scores[criterion] ?? 0
                        HStack(spacing: 8) {
                            Text(criterion.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .leading)

                            starsView(score: score)

                            Spacer()

                            Text(score == 0 ? "–" : "\(score)/3")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if hasComment {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(rating.reviewerName)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    HStack(spacing: 8) {
                        Text(String(format: "%.1f / 10", rating.averageScoreNormalizedTo10))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())

                        if let f = rating.fazitScore {
                            Text("Fazit \(f)/10")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colorForFazit(f).opacity(0.18))
                                .clipShape(Capsule())
                        } else {
                            Text("Fazit –")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }

                if hasComment {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func starsView(score: Int) -> some View {
        HStack(spacing: 6) {
            Text("–")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(score == 0 ? 1 : 0)
                .frame(width: 10, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(1...3, id: \.self) { idx in
                    Image(systemName: idx <= score ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(idx <= score ? Color.yellow : Color.secondary)
                }
            }
        }
    }

    private func colorForFazit(_ value: Int) -> Color {
        // Linear von Rot (1) nach Gruen (10)
        let clamped = min(10, max(1, value))
        let t = Double(clamped - 1) / 9.0
        let r = 1.0 - t
        let g = 0.15 + (0.85 * t)
        return Color(red: r, green: g, blue: 0.0)
    }
}
