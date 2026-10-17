//
//  MovieDiscoverySeedBuilder.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieDiscoverySeedBuilder {
    static func seedMovies(from watched: [Movie], limit: Int = 5) -> [Movie] {
        let candidates = watched.filter { $0.tmdbId != nil }
        guard !candidates.isEmpty else { return [] }

        let recentSorted = candidates.sorted {
            ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast)
        }
        let recentSeeds = Array(recentSorted.prefix(3))

        let ratedSeeds = candidates
            .compactMap { movie -> (Movie, Double)? in
                guard let rating = ownRatingBestEffort(for: movie) else { return nil }
                return (movie, rating)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return (lhs.0.watchedDate ?? .distantPast) > (rhs.0.watchedDate ?? .distantPast)
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)

        var mixed: [Movie] = []
        var seenTMDbIds = Set<Int>()
        var seenKeys = Set<String>()

        func add(_ movie: Movie) {
            if let id = movie.tmdbId {
                guard !seenTMDbIds.contains(id) else { return }
                seenTMDbIds.insert(id)
            } else {
                let key = MovieSearchMapper.key(for: movie)
                guard !seenKeys.contains(key) else { return }
                seenKeys.insert(key)
            }
            mixed.append(movie)
        }

        let maxCount = max(recentSeeds.count, ratedSeeds.count)
        for index in 0..<maxCount {
            if index < recentSeeds.count { add(recentSeeds[index]) }
            if index < ratedSeeds.count { add(ratedSeeds[index]) }
            if mixed.count >= limit { break }
        }

        if mixed.count < limit {
            for movie in recentSorted {
                add(movie)
                if mixed.count >= limit { break }
            }
        }

        return Array(mixed.prefix(limit))
    }

    private static func ownRatingBestEffort(for movie: Movie) -> Double? {
        // Prefer the group's fazit, then equally weighted reviewer criteria means.
        // Text-only contributions remain eligible as recent seeds, never as a zero score.
        movie.averageFazit ?? movie.averageRating
    }
}
