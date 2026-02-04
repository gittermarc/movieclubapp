//
//  AppearancePreviewCard.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI

struct AppearancePreviewCard: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: m.cardInnerSpacing + 4) {

            HStack(spacing: m.cardInnerSpacing + 2) {
                Label("So sieht’s aus", systemImage: "paintbrush")
                    .font(.headline)
                Spacer()
                Text("Live")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(displaySettings.tintColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: m.cardInnerSpacing + 4) {
                previewDetailRow
                Divider().opacity(0.4)
                previewCompactRow
            }
        }
        .padding(m.cardPadding + 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var previewDetailRow: some View {
        HStack(spacing: m.rowHStackSpacing) {
            posterPlaceholder(size: CGSize(width: 50, height: 75))

            VStack(alignment: .leading, spacing: 2) {
                Text("Inception")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("2010")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if displaySettings.showWatchedDate {
                        Text("• 03.02.26")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if displaySettings.showWatchedLocation {
                        Text("• Couch")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if displaySettings.showSuggestedBy {
                    Text("Vorgeschlagen von: Marc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if displaySettings.showRatings {
                let text = displaySettings.ratingDisplayMode == .ratingAverage ? "8.6" : "8.0"
                ratingPill(text: text)
            }
        }
        .padding(m.rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    private var previewCompactRow: some View {
        HStack(spacing: m.compactRowHStackSpacing) {
            if displaySettings.showPosterInCompactList {
                posterPlaceholder(size: CGSize(width: 34, height: 50))
            }

            Text("Dune: Part Two")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            if displaySettings.showRatings {
                if displaySettings.showTMDbRatingsInLists {
                    // Preview: als ob hier kein Gruppenwert vorhanden ist und TMDb als Fallback greift
                    let text = displaySettings.ratingDisplayMode == .ratingAverage ? "9.1" : "8.7"
                    ratingPill(text: text, compact: true)
                } else {
                    // Wenn TMDb in Listen deaktiviert ist, bleibt bei fehlendem Gruppenwert nur „-”
                    Text("-")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, m.compactRowVerticalPadding)
        .padding(.horizontal, m.rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    private func posterPlaceholder(size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.18))
            .frame(width: size.width, height: size.height)
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.secondary)
            }
    }

    private func ratingPill(text: String, compact: Bool = false) -> some View {
        Text(text)
            .font(compact ? .subheadline.weight(.semibold) : .headline)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(displaySettings.tintColor.opacity(compact ? 0.12 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
