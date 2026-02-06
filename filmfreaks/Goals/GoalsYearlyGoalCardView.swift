//
//  GoalsYearlyGoalCardView.swift
//  filmfreaks
//
//  Extracted from GoalsView.yearlyGoalCard
//

internal import SwiftUI

struct GoalsYearlyGoalCardView: View {

    @Binding var selectedYear: Int

    let yearOptions: [Int]
    let moviesInSelectedYear: [Movie]
    let yearlyTarget: Int
    let onSetYearlyTarget: (Int) -> Void
    let yearlyProgress: Double

    var body: some View {
        GoalCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Jahresziel \(selectedYear)")
                        .font(.headline)

                    Spacer()

                    Menu {
                        Button("Dieses Jahr") {
                            selectedYear = Calendar.current.component(.year, from: Date())
                        }
                        Divider()
                        ForEach(yearOptions, id: \.self) { y in
                            Button { selectedYear = y } label: { Text(verbatim: "\(y)") }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(verbatim: "\(selectedYear)")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(moviesInSelectedYear.count) / \(yearlyTarget) Filme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Stepper(
                            value: Binding(
                                get: { yearlyTarget },
                                set: { newValue in
                                    onSetYearlyTarget(newValue)
                                }
                            ),
                            in: 1...500,
                            step: 1
                        ) {
                            EmptyView()
                        }
                        .labelsHidden()
                    }

                    ProgressView(value: yearlyProgress)
                }

                if !moviesInSelectedYear.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(moviesInSelectedYear.prefix(30)) { m in
                                GoalMoviePosterNavTile(movie: m)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    Text(verbatim: "Noch keine Filme in \(selectedYear) markiert.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
