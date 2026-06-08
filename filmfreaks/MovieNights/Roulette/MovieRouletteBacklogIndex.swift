//
//  MovieRouletteBacklogIndex.swift
//  filmfreaks
//
//  Created by ChatGPT on 08.06.26.
//

import Foundation

/// Builds stable, group-filtered roulette backlog snapshots once per input set.
///
/// The index keeps the candidate order used by the roulette while resolving the
/// matching `Movie` values through a dictionary instead of repeated linear
/// lookups from SwiftUI.
nonisolated struct MovieRouletteBacklogIndex {
    let candidates: [MovieRouletteCandidate]
    let presetManagementMovies: [Movie]

    init(backlogMovies: [Movie], activeGroupId rawGroupId: String?) {
        let activeGroupId = Self.normalizedGroupId(rawGroupId)
        guard activeGroupId.isEmpty == false else {
            candidates = []
            presetManagementMovies = []
            return
        }

        let eligibleMovies = backlogMovies.filter { movie in
            Self.isMovie(movie, visibleIn: activeGroupId)
        }
        let moviesById = eligibleMovies.reduce(into: [UUID: Movie]()) { result, movie in
            if result.keys.contains(movie.id) == false {
                result[movie.id] = movie
            }
        }

        let sortedCandidates = eligibleMovies
            .map(MovieRouletteCandidate.init(movie:))
            .sorted(by: MovieRouletteCandidate.sortOrder)

        candidates = sortedCandidates
        presetManagementMovies = sortedCandidates.compactMap { candidate in
            moviesById[candidate.id]
        }
    }

    private static func isMovie(_ movie: Movie, visibleIn activeGroupId: String) -> Bool {
        let movieGroupId = normalizedGroupId(movie.groupId)
        if movieGroupId.isEmpty {
            return true
        }
        return movieGroupId == activeGroupId
    }

    private static func normalizedGroupId(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
