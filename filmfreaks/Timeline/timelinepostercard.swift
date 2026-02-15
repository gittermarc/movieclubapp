//
//  timelinepostercard.swift
//  filmfreaks
//

internal import SwiftUI

struct TimelinePosterCardView: View {

    static let coordinateSpaceName: String = "timelineScroll"

    @EnvironmentObject var displaySettings: DisplaySettings

    let movie: Movie
    let cardAspectRatio: CGFloat
    let parallaxStrength: CGFloat
    let parallaxClamp: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {

                // 👇 Parallax-Layer (jetzt im Poster-Format)
                parallaxPoster(movie: movie)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.60)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let dateText = movie.watchedDateText {
                            Label(dateText, systemImage: "calendar")
                        }

                        if let loc = movie.watchedLocation, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))

                    HStack(spacing: 10) {
                        Text(movie.year)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))

                        if displaySettings.showRatings {
                            let avg = displaySettings.showTMDbRatingsInLists
                            ? movie.displayAverage(for: displaySettings.ratingDisplayMode)
                            : movie.groupAverage(for: displaySettings.ratingDisplayMode)

                            if let avg {
                                Label(String(format: "%.1f", avg), systemImage: "star.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.16))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(movie.title), \(movie.year)")
    }

    /// Parallax: Bild wird minimal gegen die Scrollrichtung verschoben.
    /// Da die Card jetzt höher ist, geben wir mehr "Überhang", damit keine Lücken entstehen.
    private func parallaxPoster(movie: Movie) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(Self.coordinateSpaceName)).minY

            let raw = -minY * parallaxStrength
            let offsetY = clamp(raw, -parallaxClamp, parallaxClamp)

            let extra: CGFloat = 70 // mehr Overhang, weil höheres Posterformat

            ZStack {
                posterImage(movie: movie)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height + extra)
                    .offset(y: offsetY - (extra / 2))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(cardAspectRatio, contentMode: .fit) // 👈 HIER wird’s größer/höher
        .clipped()
    }

    @ViewBuilder
    private func posterImage(movie: Movie) -> some View {
        if let url = movie.posterURL {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.2))
                        .overlay { ProgressView() }
                case .success(let image):
                    image.resizable()
                case .failure:
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.2))
                }
            }
        } else {
            Rectangle()
                .foregroundStyle(.gray.opacity(0.18))
                .overlay {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}
