//
//  MovieRouletteSpinStripView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRouletteSpinStripView: View {

    let displayCandidates: [MovieRouletteCandidate]
    let activeDisplayIndex: Int
    let isSpinning: Bool
    let winningCandidateId: UUID?
    let sourceTitle: String

    @EnvironmentObject private var displaySettings: DisplaySettings

    var body: some View {
        GeometryReader { proxy in
            let layout = MovieRouletteSpinStripLayout.metrics(for: proxy.size)
            let targetOffset = layout.centeredOffset
                - (CGFloat(activeDisplayIndex) * layout.step)

            ZStack {
                trackBackground

                if displayCandidates.isEmpty {
                    emptyTrack(cardWidth: layout.cardWidth)
                        .padding(.horizontal, layout.horizontalInset)
                } else {
                    stripViewport(layout: layout, targetOffset: targetOffset)
                }

                VStack(spacing: 0) {
                    topPointer
                    Spacer(minLength: 0)
                    bottomPointer
                }
                .padding(.vertical, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .frame(height: 260)
    }

    private func stripViewport(layout: MovieRouletteSpinStripLayout, targetOffset: CGFloat) -> some View {
        HStack(spacing: layout.spacing) {
            ForEach(Array(displayCandidates.enumerated()), id: \.offset) { index, candidate in
                candidateCard(
                    candidate,
                    cardWidth: layout.cardWidth,
                    isWinner: candidate.id == winningCandidateId
                )
                .accessibilityLabel(accessibilityLabel(for: candidate, index: index))
            }
        }
        .offset(x: targetOffset)
        .animation(.easeOut(duration: MovieRouletteSpinEngine.animationDuration), value: activeDisplayIndex)
        .frame(width: layout.viewportWidth, alignment: .leading)
        .clipped()
        .mask {
            stripViewportMask(layout: layout)
        }
        .padding(.horizontal, layout.horizontalInset)
    }

    private func stripViewportMask(layout: MovieRouletteSpinStripLayout) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: layout.leadingFadeStop),
                        .init(color: .black, location: layout.trailingFadeStart),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    private var trackBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(.thinMaterial)

            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            displaySettings.tintColor.opacity(0.10),
                            Color.primary.opacity(0.02),
                            displaySettings.tintColor.opacity(0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
    }

    private var topPointer: some View {
        VStack(spacing: 6) {
            Capsule(style: .circular)
                .fill(displaySettings.tintColor)
                .frame(width: 76, height: 6)

            Triangle()
                .fill(displaySettings.tintColor)
                .frame(width: 18, height: 12)
                .shadow(color: displaySettings.tintColor.opacity(0.22), radius: 8, y: 3)
        }
    }

    private var bottomPointer: some View {
        Triangle()
            .fill(displaySettings.tintColor.opacity(0.8))
            .rotationEffect(.degrees(180))
            .frame(width: 16, height: 10)
            .shadow(color: displaySettings.tintColor.opacity(0.12), radius: 6, y: -2)
    }

    private func emptyTrack(cardWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Noch keine Filme im Topf")
                .font(.headline)

            Text("Sobald im Backlog der aktiven Gruppe Filme liegen, kannst du hier losschieben.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: cardWidth * 2.1)
        }
        .padding(20)
    }

    private func candidateCard(_ candidate: MovieRouletteCandidate, cardWidth: CGFloat, isWinner: Bool) -> some View {
        let posterSize = CGSize(width: cardWidth, height: cardWidth * 1.48)

        return VStack(alignment: .leading, spacing: 10) {
            GoalPosterTileView(
                posterURL: candidate.posterURL,
                size: posterSize,
                cornerRadius: displaySettings.cardCornerRadius
            )
            .overlay(alignment: .topTrailing) {
                Text(candidate.year)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule(style: .circular))
                    .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .stroke(isWinner ? displaySettings.tintColor : Color.primary.opacity(0.08), lineWidth: isWinner ? 2 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(isWinner ? "Gewinner" : sourceTitle)
                    .font(.caption)
                    .foregroundStyle(isWinner ? displaySettings.tintColor : .secondary)
            }
        }
        .padding(12)
        .frame(width: cardWidth + 24)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(isWinner ? displaySettings.tintColor.opacity(0.10) : Color.primary.opacity(0.03))
        )
        .scaleEffect(isWinner && isSpinning == false ? 1.03 : 1)
        .shadow(color: isWinner ? displaySettings.tintColor.opacity(0.16) : Color.black.opacity(0.04), radius: isWinner ? 12 : 6, y: 4)
    }

    private func accessibilityLabel(for candidate: MovieRouletteCandidate, index: Int) -> String {
        let position = index + 1
        return "\(candidate.title), \(candidate.year), Position \(position)"
    }
}

struct MovieRouletteSpinStripLayout {
    let cardWidth: CGFloat
    let spacing: CGFloat
    let step: CGFloat
    let horizontalInset: CGFloat
    let viewportWidth: CGFloat
    let fadeWidth: CGFloat

    var totalCardWidth: CGFloat {
        cardWidth + 24
    }

    var leadingFadeStop: CGFloat {
        guard viewportWidth > 0 else { return 0 }
        return min(0.18, fadeWidth / viewportWidth)
    }

    var trailingFadeStart: CGFloat {
        max(leadingFadeStop, 1 - leadingFadeStop)
    }

    var centeredOffset: CGFloat {
        (viewportWidth / 2) - (totalCardWidth / 2)
    }

    static func metrics(for size: CGSize) -> MovieRouletteSpinStripLayout {
        let isWide = size.width >= 700
        let cardWidth = isWide ? 154 : min(138, max(96, size.width * 0.28))
        let spacing: CGFloat = isWide ? 18 : 14
        let horizontalInset: CGFloat = isWide ? 22 : 16
        let viewportWidth = max(0, size.width - (horizontalInset * 2))
        let fadeWidth: CGFloat = isWide ? 56 : 44
        let step = cardWidth + 24 + spacing

        return MovieRouletteSpinStripLayout(
            cardWidth: cardWidth,
            spacing: spacing,
            step: step,
            horizontalInset: horizontalInset,
            viewportWidth: viewportWidth,
            fadeWidth: fadeWidth
        )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
