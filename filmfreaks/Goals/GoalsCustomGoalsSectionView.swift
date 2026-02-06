//
//  GoalsCustomGoalsSectionView.swift
//  filmfreaks
//
//  Extracted from GoalsView.customGoalsSection
//

internal import SwiftUI

struct GoalsCustomGoalsSectionView: View {

    let visibleGoals: [ViewingCustomGoal]
    let allGoalsCount: Int
    let selectedYear: Int

    let matchesProvider: (ViewingCustomGoal) -> [Movie]
    let onEdit: (ViewingCustomGoal) -> Void
    let onDelete: (ViewingCustomGoal) -> Void
    let onShowDetail: (ViewingCustomGoal) -> Void

    private var otherYearsCount: Int {
        max(0, allGoalsCount - visibleGoals.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom Goals")
                    .font(.headline)
                Spacer()
                Text("\(visibleGoals.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
            }

            if visibleGoals.isEmpty {
                GoalsEmptyStateView(selectedYear: selectedYear, otherYearsCount: otherYearsCount)
            } else {
                VStack(spacing: 12) {
                    ForEach(visibleGoals) { goal in
                        GoalsCustomGoalCardView(
                            goal: goal,
                            selectedYear: selectedYear,
                            matches: matchesProvider(goal),
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onShowDetail: onShowDetail
                        )
                    }
                }
            }
        }
    }
}
