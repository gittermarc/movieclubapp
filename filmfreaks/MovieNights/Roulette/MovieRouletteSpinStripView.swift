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
            let metrics = layoutMetrics(for: proxy.size)
            let targetOffset = centeredOffset(
                width: proxy.size.width,
                cardWidth: metrics.cardWidth,
                spacing: metrics.spacing
            ) - (CGFloat(activeDisplayIndex) * metrics.step)

            ZStack {
                trackBackground

                if displayCandidates.isEmpty {
                    emptyTrack(cardWidth: metrics.cardWidth)
                } else {
                    HStack(spacing: metrics.spacing) {
                        ForEach(Array(displayCandidates.enumerated()), id: \.offset) { index, candidate in
                            candidateCard(candidate, cardWidth: metrics.cardWidth, isWinner: candidate.id == winningCandidateId)
                                .accessibilityLabel(accessibilityLabel(for: candidate, index: index))
                        }
                    }
                    .offset(x: targetOffset)
                    .animation(.easeOut(duration: MovieRouletteSpinEngine.animationDuration), value: activeDisplayIndex)
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
            .overlay(alignment: .leading) {
                edgeFade
            }
            .overlay(alignment: .trailing) {
                edgeFade
                    .scaleEffect(x: -1, y: 1)
            }
        }
        .frame(height: 260)
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

    private var edgeFade: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground).opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 44)
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

    private func centeredOffset(width: CGFloat, cardWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let totalCardWidth = cardWidth + 24
        return (width / 2) - (totalCardWidth / 2)
    }

    private func layoutMetrics(for size: CGSize) -> (cardWidth: CGFloat, spacing: CGFloat, step: CGFloat) {
        let isWide = size.width >= 700
        let cardWidth = isWide ? 154 : min(138, max(96, size.width * 0.28))
        let spacing: CGFloat = isWide ? 18 : 14
        let step = cardWidth + 24 + spacing
        return (cardWidth, spacing, step)
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
