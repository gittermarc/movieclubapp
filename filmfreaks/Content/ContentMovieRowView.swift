//
//  ContentMovieRowView.swift
//  filmfreaks
//
//  Extracted from ContentView.swift
//

internal import SwiftUI

struct ContentMovieRowView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let movie: Movie
    let average: Double?

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    private var metaLine: String? {
        var parts: [String] = []

        if displaySettings.showMovieYearInLists {
            parts.append(movie.year)
        }

        if displaySettings.showWatchedDate, let dateText = movie.watchedDateText {
            parts.append(dateText)
        }

        if displaySettings.showWatchedLocation, let location = movie.watchedLocation, !location.isEmpty {
            parts.append(location)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var body: some View {
        let row = HStack(spacing: m.rowHStackSpacing) {
            // Poster
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
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 50, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                if let metaLine {
                    Text(metaLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if displaySettings.showSuggestedBy, let sugg = movie.suggestedBy, !sugg.isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if displaySettings.showRatings {
                RatingBadgeView(value: average, font: .headline, isCompactContext: false, placeholder: "-")
            }
        }

        if displaySettings.cardStyle == .cards {
            row
                .padding(m.rowPadding)
                .background(
                    RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.vertical, m.cardVerticalSpacing)
        } else {
            row
                .padding(.vertical, 8)
        }
    }
}
