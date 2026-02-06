//
//  MovieSearchRecommendationCardView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchRecommendationCardView: View {

    let result: TMDbMovieResult
    let isInWatched: Bool
    let isInBacklog: Bool

    let onOpenDetail: () -> Void
    let onAddToWatched: () -> Void
    let onAddToBacklog: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 8) {
                    poster
                        .frame(width: MovieSearchUI.recPosterWidth, height: MovieSearchUI.recPosterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .clipped()

                    Text(result.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if let year = releaseYear(from: result.release_date) {
                            Text(year)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(String(format: "%.1f", result.vote_average))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .frame(width: MovieSearchUI.recPosterWidth, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: MovieSearchUI.recCardCorner)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            menuButton
        }
    }

    private var menuButton: some View {
        Menu {
            Button(action: onOpenDetail) {
                Label("Details & Trailer", systemImage: "info.circle")
            }

            Divider()

            Button(action: onAddToWatched) {
                Label(isInWatched ? "Schon in „Gesehen“" : "Zu „Gesehen“ hinzufügen", systemImage: "checkmark.circle.fill")
            }
            .disabled(isInWatched)

            Button(action: onAddToBacklog) {
                Label(isInBacklog ? "Schon im Backlog" : "Zum Backlog hinzufügen", systemImage: "tray.full.fill")
            }
            .disabled(isInBacklog)

        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                .padding(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var poster: some View {
        if let path = result.poster_path,
           let url = URL(string: "https://image.tmdb.org/t/p/w342\(path)") {

            CachedAsyncImage(
                url: url,
                transaction: Transaction(animation: .easeOut(duration: 0.25))
            ) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.2))

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)

                case .failure:
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }

                @unknown default:
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.2))
                }
            }

        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.12))
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }
}
