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
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 50, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if displaySettings.showWatchedDate, let dateText = movie.watchedDateText {
                        Text("• \(dateText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if displaySettings.showWatchedLocation, let location = movie.watchedLocation, !location.isEmpty {
                        Text("• \(location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if displaySettings.showSuggestedBy, let sugg = movie.suggestedBy, !sugg.isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if displaySettings.showRatings {
                if let avg = average {
                    Text(String(format: "%.1f", avg))
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("-")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        if displaySettings.cardStyle == .cards {
            row
                .padding(m.rowPadding)
                .background(
                    RoundedRectangle(cornerRadius: 12)
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
