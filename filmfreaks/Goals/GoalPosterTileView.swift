//
//  GoalPosterTileView.swift
//  filmfreaks
//

internal import SwiftUI

/// Reusable poster tile used in Goals (e.g. 60x90 in cards, 40x60 in detail rows).
struct GoalPosterTileView: View {

    let posterURL: URL?
    var size: CGSize
    var cornerRadius: CGFloat

    init(movie: Movie, size: CGSize = .init(width: 60, height: 90), cornerRadius: CGFloat = 10) {
        self.posterURL = movie.posterURL
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(posterURL: URL?, size: CGSize = .init(width: 60, height: 90), cornerRadius: CGFloat = 10) {
        self.posterURL = posterURL
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let posterURL {
                CachedAsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.15))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.15))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }
}
