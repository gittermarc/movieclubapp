//
//  MovieDetailRatingInputSection.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailRatingInputSection: View {
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
                ForEach(RatingCriterion.allCases) { criterion in
                    criterionRow(criterion)
                }

                fazitRow()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Kommentar (optional)")
                        .font(.subheadline.weight(.semibold))

                    TextEditor(text: $localComment)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color.gray.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: localComment) { _, _ in
                            hasPendingRatingChanges = true
                        }
                }

                if hasPendingRatingChanges {
                    Text("Änderungen noch nicht gespeichert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onSave()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text(hasPendingRatingChanges ? "Änderungen speichern" : "Bewertung speichern")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func criterionRow(_ criterion: RatingCriterion) -> some View {
        let current = localScores[criterion] ?? 0

        VStack(alignment: .leading, spacing: 6) {
            Text(criterion.rawValue)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    localScores[criterion] = 0
                    hasPendingRatingChanges = true
                } label: {
                    Text("–")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(current == 0 ? Color.primary : Color.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(criterion.rawValue) nicht bewertet")

                ForEach(1...3, id: \.self) { value in
                    Button {
                        localScores[criterion] = value
                        hasPendingRatingChanges = true
                    } label: {
                        Image(systemName: value <= current ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(value <= current ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(criterion.rawValue) \(value) von 3")
                }

                Spacer()

                Text(current == 0 ? "– / 3" : "\(current) / 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func fazitRow() -> some View {
        let current = localFazitScore

        VStack(alignment: .leading, spacing: 6) {
            Text("Fazit (optional)")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    localFazitScore = nil
                    hasPendingRatingChanges = true
                } label: {
                    Text("–")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(current == nil ? Color.primary : Color.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fazit nicht vergeben")

                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { value in
                        Button {
                            localFazitScore = value
                            hasPendingRatingChanges = true
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForFazit(value).opacity(fazitOpacity(for: value, current: current)))
                                .frame(width: 18, height: 18)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fazit \(value) von 10")
                    }
                }

                Spacer()

                Text(current == nil ? "– / 10" : "\(current!) / 10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fazitOpacity(for value: Int, current: Int?) -> Double {
        guard let current else { return 0.22 }
        return value <= current ? 1.0 : 0.12
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
