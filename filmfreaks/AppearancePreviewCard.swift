//
//  AppearancePreviewCard.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI

struct AppearancePreviewCard: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 10) {
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

            VStack(spacing: 12) {
                previewDetailRow
                Divider().opacity(0.4)
                previewCompactRow
            }
        }
        .padding(14)
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
        HStack(spacing: 12) {
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
    }

    private var previewCompactRow: some View {
        HStack(spacing: 12) {
            if displaySettings.showPosterInCompactList {
                posterPlaceholder(size: CGSize(width: 34, height: 50))
            }

            Text("Dune: Part Two")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            if displaySettings.showRatings {
                let text = displaySettings.ratingDisplayMode == .ratingAverage ? "9.1" : "8.7"
                ratingPill(text: text, compact: true)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
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
