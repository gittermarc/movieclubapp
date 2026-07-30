//
//  MovieRatingEligibility.swift
//  filmfreaks
//
//  Central rule for rating availability.
//

import Foundation

nonisolated enum MovieRatingEligibility: Equatable, Sendable {
    case eligible
    case lockedUntilWatched
    case unavailable

    init(isBacklog: Bool) {
        self = isBacklog ? .lockedUntilWatched : .eligible
    }

    static func evaluate(
        movieID: UUID,
        watchedMovies: [Movie],
        backlogMovies: [Movie]
    ) -> MovieRatingEligibility {
        if watchedMovies.contains(where: { $0.id == movieID }) {
            return .eligible
        }

        if backlogMovies.contains(where: { $0.id == movieID }) {
            return .lockedUntilWatched
        }

        return .unavailable
    }

    var canSubmitRating: Bool {
        self == .eligible
    }

    var feedbackText: String {
        switch self {
        case .eligible:
            return "Bewertungen sind verfügbar."
        case .lockedUntilWatched:
            return "Bewertungen sind erst möglich, wenn der Film als gesehen markiert wurde."
        case .unavailable:
            return "Dieser Film ist nicht mehr verfügbar."
        }
    }
}
