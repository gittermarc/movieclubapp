//
//  MovieDetailHeroHeaderView.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailHeroHeaderView: View {
    let movie: Movie

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background (blurred)
            Group {
                if let url = movie.posterURL {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().foregroundStyle(.gray.opacity(0.15))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle().foregroundStyle(.gray.opacity(0.15))
                        @unknown default:
                            Rectangle().foregroundStyle(.gray.opacity(0.15))
                        }
                    }
                } else {
                    Rectangle().foregroundStyle(.gray.opacity(0.15))
                }
            }
            .frame(height: 320)
            .clipped()
            .blur(radius: 18)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Foreground Poster Card
            HStack(alignment: .bottom, spacing: 14) {
                poster
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    if let tmdb = movie.tmdbRating {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                            Text(String(format: "%.1f / 10", tmdb))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)

                Spacer()
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var poster: some View {
        Group {
            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).foregroundStyle(.gray.opacity(0.25))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderPoster
                    @unknown default:
                        placeholderPoster
                    }
                }
            } else {
                placeholderPoster
            }
        }
    }

    private var placeholderPoster: some View {
        Rectangle()
            .foregroundStyle(.gray.opacity(0.2))
            .overlay {
                VStack {
                    Image(systemName: "film")
                        .font(.largeTitle)
                    Text("Kein Poster verfügbar")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
    }
}
