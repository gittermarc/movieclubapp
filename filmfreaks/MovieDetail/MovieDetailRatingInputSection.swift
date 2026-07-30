//
//  MovieDetailRatingInputSection.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailRatingInputSection: View {

    @EnvironmentObject private var displaySettings: DisplaySettings
    let hasSelectedUser: Bool

    @Binding var localScores: [RatingCriterion: Int]
    @Binding var localComment: String
    @Binding var localFazitScore: Int?
    @Binding var hasPendingRatingChanges: Bool

    let onSave: () -> Void

    var body: some View {
        if !hasSelectedUser {
            Text("Bitte wähle oben in der App eine Person aus, um zu bewerten.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ziehe die Regler auf die passende Stufe. Nicht bewertete Kriterien bleiben bewusst neutral.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(RatingCriterion.allCases) { criterion in
                    criterionSlider(for: criterion)
                }

                fazitSlider

                VStack(alignment: .leading, spacing: 8) {
                    Text("Kommentar (optional)")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $localComment)
                        .font(.body)
                        .frame(minHeight: 100)
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(displaySettings.tintStroke.opacity(0.65), lineWidth: 1)
                        }
                        .onChange(of: localComment) { _, _ in
                            hasPendingRatingChanges = true
                        }
                }

                if hasPendingRatingChanges {
                    Label("Änderungen noch nicht gespeichert.", systemImage: "circle.dashed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onSave()
                } label: {
                    Label(
                        hasPendingRatingChanges ? "Änderungen speichern" : "Bewertung speichern",
                        systemImage: "square.and.arrow.down"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(
                    displaySettings.tintActionBackground,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
        }
    }

    private func criterionSlider(for criterion: RatingCriterion) -> some View {
        RatingGlassSlider(
            title: criterion.rawValue,
            value: scoreBinding(for: criterion),
            range: 0...3,
            unselectedValue: 0,
            unselectedText: "Nicht bewertet",
            valueText: { value in
                "\(value) / 3"
            },
            accentColor: { _ in
                displaySettings.tintColor
            }
        ) {
            hasPendingRatingChanges = true
        }
    }

    private var fazitSlider: some View {
        RatingGlassSlider(
            title: "Fazit (optional)",
            value: fazitScoreBinding,
            range: 0...10,
            unselectedValue: 0,
            unselectedText: "Nicht vergeben",
            valueText: { value in
                MovieRatingFazitScale.scoreText(value)
            },
            accentColor: { value in
                MovieRatingFazitScale.color(for: value == 0 ? nil : value)
            },
            spectrumColors: MovieRatingFazitScale.gradientColors
        ) {
            hasPendingRatingChanges = true
        }
    }

    private func scoreBinding(for criterion: RatingCriterion) -> Binding<Int> {
        Binding(
            get: {
                localScores[criterion] ?? 0
            },
            set: { newValue in
                localScores[criterion] = newValue
            }
        )
    }

    private var fazitScoreBinding: Binding<Int> {
        Binding(
            get: {
                localFazitScore ?? 0
            },
            set: { newValue in
                localFazitScore = newValue == 0 ? nil : newValue
            }
        )
    }
}
