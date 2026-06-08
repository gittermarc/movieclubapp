//
//  MovieRouletteCandidatesCard.swift
//  filmfreaks
//
//  Created by ChatGPT on 08.06.26.
//

import Foundation
internal import SwiftUI

struct MovieRouletteCandidatesCard: View {
    @EnvironmentObject private var displaySettings: DisplaySettings
    @ObservedObject var viewModel: MovieRouletteViewModel

    let onManagePresets: () -> Void

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        if viewModel.candidates.isEmpty {
            emptyCard
        } else {
            populatedCard
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(viewModel.emptyStateTitle, systemImage: "film.stack")
                .font(.headline)

            Text(viewModel.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.selectedSource == .preset, viewModel.canManagePresets {
                Button("Auswahlen verwalten") {
                    onManagePresets()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(m.cardPadding + 2)
        .background(cardBackground)
    }

    private var populatedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(viewModel.selectedSource == .preset ? "In Auswahl" : "Im Topf", systemImage: "movieclapper")
                    .font(.headline)

                Spacer(minLength: 12)

                Text(viewModel.candidateCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            candidatePosterRow

            let previewTitles = candidatePreviewText(from: viewModel.candidates)
            if previewTitles.isEmpty == false {
                Text(previewTitles)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(m.cardPadding + 2)
        .background(cardBackground)
    }

    private var candidatePosterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.candidates.prefix(10))) { candidate in
                    VStack(alignment: .leading, spacing: 6) {
                        GoalPosterTileView(
                            posterURL: candidate.posterURL,
                            size: .init(width: 78, height: 117),
                            cornerRadius: displaySettings.cardCornerRadius
                        )
                        Text(candidate.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .frame(width: 78, alignment: .leading)
                    }
                    .frame(width: 78, alignment: .leading)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func candidatePreviewText(from candidates: [MovieRouletteCandidate]) -> String {
        let previewTitles = candidates.prefix(4).map(\.title)
        guard previewTitles.isEmpty == false else { return "" }

        let joined = ListFormatter.localizedString(byJoining: previewTitles)
        let remainingCount = candidates.count - previewTitles.count
        if remainingCount > 0 {
            return "Zum Beispiel: \(joined) und \(remainingCount) weitere."
        }
        return "Im Rennen: \(joined)."
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
