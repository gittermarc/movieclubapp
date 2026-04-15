//
//  MovieRouletteCandidate.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

/// Lightweight movie candidate derived from the current group's backlog.
nonisolated struct MovieRouletteCandidate: Identifiable, Equatable, Hashable {
    let movieRef: MovieNightMovieRef
    let addedAt: Date?

    nonisolated var id: UUID { movieRef.movieId }
    nonisolated var title: String { movieRef.title }
    nonisolated var year: String { movieRef.year }
    nonisolated var posterURL: URL? { movieRef.posterURL }

    init(movieRef: MovieNightMovieRef, addedAt: Date?) {
        self.movieRef = movieRef
        self.addedAt = addedAt
    }

    init(movie: Movie) {
        self.init(movieRef: MovieNightMovieRef(movie: movie), addedAt: movie.addedAt)
    }
}

extension MovieRouletteCandidate {

    nonisolated static func buildPresetCandidates(from preset: MovieRoulettePreset?) -> [MovieRouletteCandidate] {
        guard let preset else { return [] }
        return preset.movieRefs.map { MovieRouletteCandidate(movieRef: $0, addedAt: nil) }
    }

    nonisolated static func buildBacklogCandidates(from movies: [Movie], activeGroupId rawGroupId: String?) -> [MovieRouletteCandidate] {
        let activeGroupId = normalizedGroupId(rawGroupId)
        guard !activeGroupId.isEmpty else { return [] }

        return movies
            .filter { movie in
                let movieGroupId = normalizedGroupId(movie.groupId)
                if movieGroupId.isEmpty {
                    return true
                }
                return movieGroupId == activeGroupId
            }
            .map(MovieRouletteCandidate.init(movie:))
            .sorted(by: sortOrder)
    }

    nonisolated static func sortOrder(lhs: MovieRouletteCandidate, rhs: MovieRouletteCandidate) -> Bool {
        let lhsAddedAt = lhs.addedAt ?? .distantPast
        let rhsAddedAt = rhs.addedAt ?? .distantPast
        if lhsAddedAt != rhsAddedAt {
            return lhsAddedAt > rhsAddedAt
        }

        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }

        return lhs.year.localizedCaseInsensitiveCompare(rhs.year) == .orderedAscending
    }

    nonisolated private static func normalizedGroupId(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
