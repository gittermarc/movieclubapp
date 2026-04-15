//
//  MovieRouletteResultCard.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRouletteResultCard: View {

    let candidate: MovieRouletteCandidate
    let sourceTitle: String
    let message: String
    let onSuggestMovieNight: () -> Void
    let onSpinAgain: () -> Void
    let onRemoveWinnerAndSpinAgain: (() -> Void)?

    @EnvironmentObject private var displaySettings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label {
                    Text("Gewinnerfilm")
                        .font(.headline)
                } icon: {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(displaySettings.tintColor)
                }

                Spacer(minLength: 12)

                Text(sourceTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(displaySettings.tintColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .circular)
                            .fill(displaySettings.tintColor.opacity(0.12))
                    )
            }

            HStack(alignment: .top, spacing: 14) {
                GoalPosterTileView(
                    posterURL: candidate.posterURL,
                    size: .init(width: 82, height: 122),
                    cornerRadius: displaySettings.cardCornerRadius
                )
                .overlay(alignment: .bottomTrailing) {
                    Text(candidate.year)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule(style: .circular))
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(3)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                onSuggestMovieNight()
            } label: {
                Label("Als Filmabend vorschlagen", systemImage: "calendar.badge.plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(displaySettings.tintColor)

            HStack(spacing: 10) {
                Button {
                    onSpinAgain()
                } label: {
                    Label("Nochmal drehen", systemImage: "arrow.clockwise.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let onRemoveWinnerAndSpinAgain {
                    Button(role: .destructive) {
                        onRemoveWinnerAndSpinAgain()
                    } label: {
                        Label("Gewinner raus", systemImage: "minus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
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
