//
//  GoalsCustomGoalCardView.swift
//  filmfreaks
//
//  Extracted from GoalsView.customGoalCard(_:)
//

internal import SwiftUI

struct GoalsCustomGoalCardView: View {

    @EnvironmentObject var displaySettings: DisplaySettings

    let goal: ViewingCustomGoal
    let selectedYear: Int
    let matches: [Movie]

    let onEdit: (ViewingCustomGoal) -> Void
    let onDelete: (ViewingCustomGoal) -> Void
    let onShowDetail: (ViewingCustomGoal) -> Void

    private var progress: Double {
        guard goal.target > 0 else { return 0 }
        return min(1.0, Double(matches.count) / Double(goal.target))
    }

    var body: some View {
        GoalCardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    GoalLeadingBadgeView(goal: goal)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)

                        Text(goal.validityLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(matches.count) / \(goal.target)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Menu {
                        Button {
                            onEdit(goal)
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete(goal)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }

                ProgressView(value: progress)

                if !matches.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(matches.prefix(18)) { m in
                                GoalMoviePosterNavTile(movie: m)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    Text(verbatim: "Noch keine passenden Filme in \(selectedYear).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onShowDetail(goal)
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Passende Filme anzeigen")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(displaySettings.tint(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
