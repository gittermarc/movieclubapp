//
//  GroupActivityRowView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

struct GroupActivityRowView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    let event: GroupActivityEvent

    private enum MovieLocation {
        case watched(Int)
        case backlog(Int)
    }

    private var actorName: String {
        let trimmed = (event.actorName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Jemand" : trimmed
    }

    private var verbText: String {
        switch event.kind {
        case .movieAdded:
            return "hat hinzugefügt"
        case .movieRated:
            return "hat bewertet"
        }
    }

    private var kindBadgeSystemImage: String {
        switch event.kind {
        case .movieAdded:
            return "plus"
        case .movieRated:
            return "star.fill"
        }
    }

    private var movieText: String {
        if let y = event.movieYear, !y.isEmpty {
            return "\(event.movieTitle) (\(y))"
        }
        return event.movieTitle
    }

    private var relativeTimeText: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: event.date, relativeTo: Date())
    }

    private var headlineAttributedText: AttributedString {
        var result = AttributedString(actorName)
        result.font = .subheadline.weight(.semibold)

        var rest = AttributedString(" \(verbText) \(movieText)")
        rest.font = .subheadline

        result += rest
        return result
    }

    private var movieLocation: MovieLocation? {
        if let idx = movieStore.movies.firstIndex(where: { $0.id == event.movieId }) {
            return .watched(idx)
        }
        if let idx = movieStore.backlogMovies.firstIndex(where: { $0.id == event.movieId }) {
            return .backlog(idx)
        }
        return nil
    }

    var body: some View {
        Group {
            if let movieLocation {
                NavigationLink {
                    destination(for: movieLocation)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            ActivityAvatarView(name: actorName, badgeSystemImage: kindBadgeSystemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(headlineAttributedText)
                    .lineLimit(2)

                Text(relativeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if event.kind == .movieRated {
                RatingBadgeView(value: event.ratingValue, font: .subheadline, isCompactContext: true, placeholder: "-")
                    .environmentObject(displaySettings)
            }

            poster
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .foregroundStyle(.primary)
        .accessibilityHint("Öffnet den Film")
    }

    @ViewBuilder
    private func destination(for location: MovieLocation) -> some View {
        switch location {
        case .watched(let idx):
            if movieStore.movies.indices.contains(idx) {
                MovieDetailView(
                    movie: $movieStore.movies[idx],
                    isBacklog: false
                )
            } else {
                missingMovieDestination
            }

        case .backlog(let idx):
            if movieStore.backlogMovies.indices.contains(idx) {
                MovieDetailView(
                    movie: $movieStore.backlogMovies[idx],
                    isBacklog: true
                )
            } else {
                missingMovieDestination
            }
        }
    }

    private var missingMovieDestination: some View {
        ContentUnavailableView(
            "Film nicht gefunden",
            systemImage: "film",
            description: Text("Der Film ist nicht mehr in deiner aktuellen Gruppe vorhanden.")
        )
        .padding()
    }

    private var poster: some View {
        Group {
            if let url = event.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.12))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }
        }
        .frame(width: 28, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius))
    }

}
