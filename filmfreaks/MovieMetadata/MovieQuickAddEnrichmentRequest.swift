//
//  MovieQuickAddEnrichmentRequest.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieQuickAddEnrichmentRequest: Equatable, Sendable {
    let movieId: UUID
    let tmdbId: Int
    let isBacklog: Bool
    let movieSnapshot: Movie

    init?(movie: Movie, isBacklog: Bool) {
        guard let tmdbId = movie.tmdbId else { return nil }
        self.movieId = movie.id
        self.tmdbId = tmdbId
        self.isBacklog = isBacklog
        self.movieSnapshot = movie
    }
}
