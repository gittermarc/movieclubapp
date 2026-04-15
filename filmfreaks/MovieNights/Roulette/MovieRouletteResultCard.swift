//
//  MovieRouletteResultCard.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRouletteResultCard: View {

    let candidate: MovieRouletteCandidate
    let groupName: String
    let onSpinAgain: () -> Void

    @EnvironmentObject private var displaySettings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Gewinnerfilm")
                    .font(.headline)
            } icon: {
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(displaySettings.tintColor)
            }

            HStack(alignment: .top, spacing: 14) {
                GoalPosterTileView(
                    posterURL: candidate.posterURL,
                    size: .init(width: 82, height: 122),
                    cornerRadius: displaySettings.cardCornerRadius
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(3)

                    Text(candidate.year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Das Roulette hat für \(groupName) diesen Backlog-Film nach vorne geschoben.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                onSpinAgain()
            } label: {
                Label("Nochmal drehen", systemImage: "arrow.clockwise.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(displaySettings.tintColor)
        }
        .padding(displaySettings.metrics.cardPadding + 2)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                        .stroke(displaySettings.tintColor.opacity(0.16), lineWidth: 1)
                }
        )
    }
}
