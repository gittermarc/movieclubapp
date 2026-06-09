//
//  MovieRouletteStageCard.swift
//  filmfreaks
//
//  Created by Marc Fechner on 08.06.26.
//

internal import SwiftUI

struct MovieRouletteStageCard: View {
    @EnvironmentObject private var displaySettings: DisplaySettings
    @ObservedObject var viewModel: MovieRouletteViewModel

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Marker entscheidet")
                .font(.headline)

            Text(viewModel.stageDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MovieRouletteSpinStripView(
                displayCandidates: viewModel.displayCandidates,
                activeDisplayIndex: viewModel.activeDisplayIndex,
                isSpinning: viewModel.isSpinning,
                winningCandidateId: viewModel.winningCandidate?.id,
                sourceTitle: viewModel.selectedSource.title
            )
            .environmentObject(displaySettings)

            Button {
                viewModel.spin()
            } label: {
                Label(viewModel.spinButtonTitle, systemImage: viewModel.isSpinning ? "sparkles.rectangle.stack" : "play.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(displaySettings.tintColor)
            .disabled(viewModel.candidates.isEmpty || viewModel.isSpinning)
        }
        .padding(m.cardPadding + 2)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
