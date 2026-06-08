//
//  MovieStore+QuickAdd.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieStoreAddDestination: Equatable, Sendable {
    case watched
    case backlog

    var isBacklog: Bool {
        switch self {
        case .watched:
            return false
        case .backlog:
            return true
        }
    }
}

nonisolated struct MovieStoreAddResult: Sendable {
    let movie: Movie
    let destination: MovieStoreAddDestination
    let didInsert: Bool
}

@MainActor
extension MovieStore {
    @discardableResult
    func addMovie(
        _ newMovie: Movie,
        to destination: MovieStoreAddDestination,
        selectedUser: User?,
        setsWatchedDateIfMissing: Bool = false,
        enrichmentQueue: MovieQuickAddEnrichmentQueue? = nil
    ) -> MovieStoreAddResult? {
        var movieWithContext = movieWithGroupContext(newMovie, selectedUser: selectedUser)
        if destination == .watched, setsWatchedDateIfMissing, movieWithContext.watchedDate == nil {
            movieWithContext.watchedDate = Date()
        }

        let result: MovieStoreAddResult?
        switch destination {
        case .watched:
            result = addMovieToWatchedList(movieWithContext)
        case .backlog:
            result = addMovieToBacklogList(movieWithContext)
        }

        if let result {
            enqueueQuickAddEnrichmentIfNeeded(
                for: result.movie,
                isBacklog: result.destination.isBacklog,
                queue: enrichmentQueue
            )
        }

        return result
    }

    func enqueueQuickAddEnrichmentIfNeeded(
        for movie: Movie,
        isBacklog: Bool,
        queue: MovieQuickAddEnrichmentQueue? = nil
    ) {
        guard let request = MovieQuickAddEnrichmentRequest(movie: movie, isBacklog: isBacklog) else {
            return
        }
        guard MovieQuickAddEnrichmentService.needsEnrichment(movie: movie) else {
            return
        }
        let enrichmentQueue = queue ?? MovieQuickAddEnrichmentQueue.shared

        Task { [weak self] in
            guard let patch = await enrichmentQueue.loadPatch(for: request) else {
                return
            }
            self?.applyLoadedMoviePatch(patch, toMovieId: request.movieId, isBacklog: request.isBacklog)
        }
    }

    private func addMovieToWatchedList(_ movie: Movie) -> MovieStoreAddResult {
        let matches: (Movie) -> Bool = { existing in
            Self.metadataMovie(existing, matches: movie)
        }

        if let existing = movies.first(where: matches) {
            backlogMovies.removeAll(where: matches)
            return MovieStoreAddResult(movie: existing, destination: .watched, didInsert: false)
        }

        movies.append(movie)
        backlogMovies.removeAll(where: matches)
        return MovieStoreAddResult(movie: movie, destination: .watched, didInsert: true)
    }

    private func addMovieToBacklogList(_ movie: Movie) -> MovieStoreAddResult? {
        let matches: (Movie) -> Bool = { existing in
            Self.metadataMovie(existing, matches: movie)
        }

        if movies.contains(where: matches) {
            return nil
        }

        if let existing = backlogMovies.first(where: matches) {
            return MovieStoreAddResult(movie: existing, destination: .backlog, didInsert: false)
        }

        backlogMovies.append(movie)
        return MovieStoreAddResult(movie: movie, destination: .backlog, didInsert: true)
    }

    private func movieWithGroupContext(_ movie: Movie, selectedUser: User?) -> Movie {
        var movieWithContext = movie
        movieWithContext.groupId = currentGroupId
        movieWithContext.groupName = currentGroupName

        if movieWithContext.addedAt == nil {
            movieWithContext.addedAt = Date()
        }

        if (movieWithContext.addedByName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           let selectedUser {
            movieWithContext.addedById = selectedUser.id
            movieWithContext.addedByName = selectedUser.name
        }

        return movieWithContext
    }

    nonisolated static func metadataMovie(_ existing: Movie, matches candidate: Movie) -> Bool {
        if let existingTMDbId = existing.tmdbId,
           let candidateTMDbId = candidate.tmdbId,
           existingTMDbId == candidateTMDbId {
            return true
        }

        return existing.title.caseInsensitiveCompare(candidate.title) == .orderedSame
            && existing.year == candidate.year
    }
}
