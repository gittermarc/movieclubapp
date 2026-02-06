//
//  ContentCompactMovieRowView.swift
//  filmfreaks
//
//  Extracted from ContentView.swift
//

internal import SwiftUI

struct ContentCompactMovieRowView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let movie: Movie
    let average: Double?

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        let row = HStack(spacing: m.compactRowHStackSpacing) {
            if displaySettings.showPosterInCompactList {
                if let url = movie.posterURL {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.2))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.2))
                                .overlay {
                                    Image(systemName: "film")
                                }
                        @unknown default:
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.2))
                        }
                    }
                    .frame(width: 34, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius))
                } else {
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.12))
                        .frame(width: 34, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius))
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                }
            }

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            if displaySettings.showRatings {
                if let avg = average {
                    Text(String(format: "%.1f", avg))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: displaySettings.pillCornerRadius))
                } else {
                    Text("-")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }

        if displaySettings.cardStyle == .cards {
            row
                .padding(.vertical, m.compactRowVerticalPadding)
                .padding(.horizontal, m.rowPadding)
                .background(
                    RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                .padding(.vertical, m.cardVerticalSpacing)
        } else {
            row
                .padding(.vertical, m.compactRowVerticalPadding)
        }
    }
}
