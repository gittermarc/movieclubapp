//
//  MovieMetadataMembershipPresentation.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieMetadataMembershipState: Equatable, Sendable {
    case current
    case watched
    case backlog
    case missing

    var title: String {
        switch self {
        case .current:
            return "Aktueller Film"
        case .watched:
            return "Gesehen"
        case .backlog:
            return "Im Backlog"
        case .missing:
            return "Fehlt noch"
        }
    }

    var systemImage: String {
        switch self {
        case .current:
            return "play.circle.fill"
        case .watched:
            return "checkmark.circle.fill"
        case .backlog:
            return "tray.full.fill"
        case .missing:
            return "plus.circle"
        }
    }

    var isKnownListMember: Bool {
        switch self {
        case .watched, .backlog, .current:
            return true
        case .missing:
            return false
        }
    }
}

nonisolated enum MovieMetadataMembershipResolver {
    static func state(
        tmdbId: Int?,
        title: String,
        year: String?,
        currentTMDbId: Int?,
        watchedMovies: [Movie],
        backlogMovies: [Movie]
    ) -> MovieMetadataMembershipState {
        if let tmdbId, let currentTMDbId, tmdbId == currentTMDbId {
            return .current
        }

        if containsMovie(tmdbId: tmdbId, title: title, year: year, in: watchedMovies) {
            return .watched
        }

        if containsMovie(tmdbId: tmdbId, title: title, year: year, in: backlogMovies) {
            return .backlog
        }

        return .missing
    }

    static func containsMovie(
        tmdbId: Int?,
        title: String,
        year: String?,
        in movies: [Movie]
    ) -> Bool {
        if let tmdbId, movies.contains(where: { $0.tmdbId == tmdbId }) {
            return true
        }

        let normalizedTitle = normalized(title)
        let normalizedYear = normalized(year ?? "n/a")
        guard !normalizedTitle.isEmpty else { return false }

        return movies.contains { movie in
            normalized(movie.title) == normalizedTitle && normalized(movie.year) == normalizedYear
        }
    }

    static func result(
        from part: TMDbCollectionPart
    ) -> TMDbMovieResult {
        TMDbMovieResult(
            id: part.id,
            title: part.title,
            release_date: part.release_date,
            vote_average: part.vote_average,
            poster_path: part.poster_path,
            backdrop_path: part.backdrop_path
        )
    }

    static func year(from releaseDate: String?) -> String? {
        guard let releaseDate else { return nil }
        let trimmed = releaseDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return nil }
        return String(trimmed.prefix(4))
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
