//
//  MovieDiscoveryMembershipResolver.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieDiscoveryMembershipResolver {
    static func isKnown(
        _ result: TMDbMovieResult,
        watched: [Movie],
        backlog: [Movie],
        localWatchedKeys: Set<String>,
        localBacklogKeys: Set<String>
    ) -> Bool {
        let resultKey = MovieSearchMapper.key(for: result)
        if localWatchedKeys.contains(resultKey) || localBacklogKeys.contains(resultKey) {
            return true
        }

        if watched.contains(where: { matches(result, movie: $0) }) { return true }
        if backlog.contains(where: { matches(result, movie: $0) }) { return true }
        return false
    }

    static func matches(_ result: TMDbMovieResult, movie: Movie) -> Bool {
        if let tmdbId = movie.tmdbId, tmdbId == result.id {
            return true
        }
        return MovieSearchMapper.key(for: result) == MovieSearchMapper.key(for: movie)
    }
}
