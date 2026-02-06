//
//  MovieSearchResultCardView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchResultCardView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let result: TMDbMovieResult
    let isInWatched: Bool
    let isInBacklog: Bool

    let onOpenDetail: () -> Void
    let onAddToWatched: () -> Void
    let onAddToBacklog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {

                Button(action: onOpenDetail) {
                    HStack(alignment: .top, spacing: 12) {
                        posterThumbnail

                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.title)
                                .font(.headline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 10) {
                                if let year = releaseYear(from: result.release_date) {
                                    Label(year, systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Label(String(format: "%.1f / 10", result.vote_average), systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if isInWatched || isInBacklog {
                                HStack(spacing: 6) {
                                    if isInWatched {
                                        Label("In „Gesehen“", systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    if isInBacklog {
                                        Label("Im Backlog", systemImage: "tray.full.fill")
                                            .font(.caption2)
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(displaySettings.tintUltraSoftBackground)
                                .clipShape(Capsule())
                            }

                            detailsHintChip
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

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
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text("Hinzufügen")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: MovieSearchUI.cardCorner)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var detailsHintChip: some View {
        HStack(spacing: 6) {
            Text("Details")
                .font(.caption.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(displaySettings.tintStroke, lineWidth: 1)
        }
        .shadow(color: displaySettings.tintShadowStrong, radius: 10, x: 0, y: 2)
        .shadow(color: displaySettings.tintShadowSoft, radius: 18, x: 0, y: 8)
    }

    private var posterThumbnail: some View {
        let ratingText = String(format: "%.1f", result.vote_average)

        return Group {
            if let path = result.poster_path,
               let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {

                CachedAsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeOut(duration: 0.25))
                ) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)

                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }

                    @unknown default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: MovieSearchUI.posterWidth, height: MovieSearchUI.posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .clipped()

            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: MovieSearchUI.posterWidth, height: MovieSearchUI.posterHeight)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            Text(ratingText)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(6)
        }
    }

    private func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }
}
