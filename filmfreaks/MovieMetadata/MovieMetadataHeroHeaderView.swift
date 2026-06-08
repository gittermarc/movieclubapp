//
//  MovieMetadataHeroHeaderView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieMetadataHeroHeaderView: View {
    let posterURL: URL?
    let backdropURL: URL?
    let posterFallbackBackgroundURL: URL?
    let title: String
    let yearText: String?
    let tmdbRating: Double?
    let groupRating: Double?
    let runtimeText: String?
    let certificationText: String?

    private let heroHeight: CGFloat = 320

    private var backgroundURL: URL? {
        backdropURL ?? posterFallbackBackgroundURL
    }

    private var usesPosterFallbackBackground: Bool {
        backdropURL == nil && posterFallbackBackgroundURL != nil
    }

    var body: some View {
        GeometryReader { proxy in
            heroContent(width: max(proxy.size.width, 1))
        }
        .frame(height: heroHeight)
        .frame(maxWidth: .infinity)
    }

    private func heroContent(width: CGFloat) -> some View {
        let posterWidth = min(120, max(96, width * 0.32))
        let posterHeight = posterWidth * 1.5
        let textColumnWidth = max(92, width - posterWidth - 46)

        return ZStack(alignment: .bottomLeading) {
            backgroundImage
                .frame(width: width, height: heroHeight)
                .clipped()
                .blur(radius: usesPosterFallbackBackground ? 14 : 0)
                .overlay(backgroundGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            HStack(alignment: .bottom, spacing: 14) {
                poster
                    .frame(width: posterWidth, height: posterHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let yearText {
                        Text(yearText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.86))
                    }

                    if let tmdbRating {
                        MovieMetadataHeroChipView(
                            systemImage: "star.fill",
                            text: String(format: "TMDb %.1f", tmdbRating)
                        )
                    }

                    if let groupRating {
                        MovieMetadataHeroChipView(
                            systemImage: "person.3.fill",
                            text: String(format: "Gruppe %.1f", groupRating)
                        )
                    }

                    heroChips

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)
                .frame(maxWidth: textColumnWidth, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(width: width, height: heroHeight, alignment: .bottomLeading)
        }
        .frame(width: width, height: heroHeight, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var heroChips: some View {
        let chipTexts = [runtimeText, certificationText]
            .compactMap { value -> String? in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }

        if !chipTexts.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(chipTexts, id: \.self) { text in
                        heroTextChip(text)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(chipTexts, id: \.self) { text in
                        heroTextChip(text)
                    }
                }
            }
        }
    }

    private func heroTextChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.16))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var backgroundImage: some View {
        if let backgroundURL {
            CachedAsyncImage(url: backgroundURL) { phase in
                switch phase {
                case .empty:
                    placeholderBackground
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderBackground
                @unknown default:
                    placeholderBackground
                }
            }
        } else {
            placeholderBackground
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.58),
                Color.black.opacity(backdropURL == nil ? 0.18 : 0.08),
                Color.black.opacity(0.66)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var poster: some View {
        if let posterURL {
            CachedAsyncImage(url: posterURL) { phase in
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

    private var placeholderBackground: some View {
        Rectangle().foregroundStyle(.gray.opacity(0.15))
    }

    private var placeholderPoster: some View {
        Rectangle()
            .foregroundStyle(.gray.opacity(0.2))
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "film")
                        .font(.largeTitle)
                    Text("Kein Poster verfügbar")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(8)
            }
    }
}

private struct MovieMetadataHeroChipView: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.94))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.28))
        .clipShape(Capsule())
    }
}
