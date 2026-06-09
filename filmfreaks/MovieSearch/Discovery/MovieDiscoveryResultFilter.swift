//
//  MovieDiscoveryResultFilter.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieDiscoveryResultFilter {
    static func filteredResults(
        _ results: [TMDbMovieResult],
        request: MovieDiscoveryRequest,
        currentMovieID: Int? = nil
    ) -> [TMDbMovieResult] {
        var seen = Set<Int>()
        var output: [TMDbMovieResult] = []

        for result in results {
            if let currentMovieID, result.id == currentMovieID { continue }
            guard !seen.contains(result.id) else { continue }
            seen.insert(result.id)

            if MovieDiscoveryMembershipResolver.isKnown(
                result,
                watched: request.existingWatched,
                backlog: request.existingBacklog,
                localWatchedKeys: request.localWatchedKeys,
                localBacklogKeys: request.localBacklogKeys
            ) {
                continue
            }

            output.append(result)
            if output.count >= request.limitPerShelf { break }
        }

        return output
    }
}
