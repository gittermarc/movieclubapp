//
//  ContentPosterGridCellView.swift
//  filmfreaks
//
//  Extracted from ContentView.swift
//

internal import SwiftUI

struct ContentPosterGridCellView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let movie: Movie

    private var g: DisplaySettings.PosterGridMetrics { displaySettings.posterGridMetrics }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: g.cellHeight)
        .clipped()
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
