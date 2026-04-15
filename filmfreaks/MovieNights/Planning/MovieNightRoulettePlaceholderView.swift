//
//  MovieNightRoulettePlaceholderView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

/// PR 1 placeholder for the future Filmroulette area.
struct MovieNightRoulettePlaceholderView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                heroCard

                ForEach(MovieNightRoulettePlaceholderPresentation.highlights) { highlight in
                    highlightCard(highlight)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Filmroulette")
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: "sparkles.tv")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
            }

            Text(MovieNightRoulettePlaceholderPresentation.introText(for: movieStore.currentGroupName))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .symbolRenderingMode(.hierarchical)
                Text("Der Bereich ist vorbereitet und bekommt im nächsten PR die erste interaktive Spin-Ansicht.")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .circular)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding(m.cardPadding)
        .background(cardBackground)
    }

    private func highlightCard(_ highlight: MovieNightRoulettePlaceholderPresentation.Highlight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: highlight.systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.title)
                    .font(.headline)
                Text(highlight.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(m.cardPadding)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        MovieNightRoulettePlaceholderView()
            .navigationTitle("Filmroulette")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(MovieStore.preview())
    .environmentObject(DisplaySettings())
}
