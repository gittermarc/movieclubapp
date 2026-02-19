//
//  MovieStore+Activity.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

import Foundation

internal extension MovieStore {

    /// Builds a list of "recent activity" events for the current group.
    ///
    /// The feed is derived from:
    /// - Movie metadata: `addedAt`, `addedByName` (set when a movie is added)
    /// - Ratings: `Rating.updatedAt` (taken from the CloudKit record `updatedAt`)
    ///
    /// NOTE: We intentionally keep this purely derived to avoid additional CloudKit schema changes.
    func activityEvents(displayMode: RatingDisplayMode, limit: Int? = nil) -> [GroupActivityEvent] {
        let allMovies = movies + backlogMovies
        guard !allMovies.isEmpty else { return [] }

        var events: [GroupActivityEvent] = []
        events.reserveCapacity(allMovies.count * 2)

        for movie in allMovies {
            if let addedAt = movie.addedAt {
                let actorName = firstNonEmpty(movie.addedByName, movie.suggestedBy)
                events.append(
                    GroupActivityEvent(
                        kind: .movieAdded,
                        date: addedAt,
                        actorName: actorName,
                        actorId: movie.addedById,
                        movieId: movie.id,
                        movieTitle: movie.title,
                        movieYear: movie.year,
                        posterPath: movie.posterPath,
                        ratingValue: nil
                    )
                )
            }

            for rating in movie.ratings {
                guard let date = rating.updatedAt else { continue }
                let value = ratingValue(for: rating, displayMode: displayMode)

                events.append(
                    GroupActivityEvent(
                        kind: .movieRated,
                        date: date,
                        actorName: rating.reviewerName,
                        actorId: rating.reviewerId,
                        movieId: movie.id,
                        movieTitle: movie.title,
                        movieYear: movie.year,
                        posterPath: movie.posterPath,
                        ratingValue: value
                    )
                )
            }
        }

        events.sort { $0.date > $1.date }

        if let limit {
            return Array(events.prefix(limit))
        }
        return events
    }
}

private func firstNonEmpty(_ a: String?, _ b: String?) -> String? {
    if let a, !a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return a }
    if let b, !b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return b }
    return nil
}

private func ratingValue(for rating: Rating, displayMode: RatingDisplayMode) -> Double? {
    switch displayMode {
    case .ratingAverage:
        let value = rating.averageScoreNormalizedTo10
        return value <= 0 ? nil : value
    case .fazitAverage:
        if let fs = rating.fazitScore {
            return Double(fs)
        }
        let fallback = rating.averageScoreNormalizedTo10
        return fallback <= 0 ? nil : fallback
    }
}
