//
//  MovieDetailView+MetadataActions.swift
//  filmfreaks
//

internal import SwiftUI

extension MovieDetailView {
    func openMetadataDetail(_ result: TMDbMovieResult) {
        metadataDetailResult = result
    }

    func addMetadataResultToBacklog(_ result: TMDbMovieResult) {
        addMetadataMovieToBacklog(MovieSearchMapper.convertToMovie(result))
    }

    func addMetadataMovieToWatched(_ movie: Movie) {
        var movieWithContext = movieWithGroupContext(movie)
        if movieWithContext.watchedDate == nil {
            movieWithContext.watchedDate = Date()
        }

        let matches: (Movie) -> Bool = { existing in
            metadataMovie(existing, matches: movieWithContext)
        }

        if !movieStore.movies.contains(where: matches) {
            movieStore.movies.append(movieWithContext)
        }

        movieStore.backlogMovies.removeAll(where: matches)
    }

    func addMetadataMovieToBacklog(_ movie: Movie) {
        let movieWithContext = movieWithGroupContext(movie)

        let matches: (Movie) -> Bool = { existing in
            metadataMovie(existing, matches: movieWithContext)
        }

        guard !movieStore.movies.contains(where: matches) else { return }

        if !movieStore.backlogMovies.contains(where: matches) {
            movieStore.backlogMovies.append(movieWithContext)
        }
    }

    private func movieWithGroupContext(_ movie: Movie) -> Movie {
        var movieWithContext = movie
        movieWithContext.groupId = movieStore.currentGroupId
        movieWithContext.groupName = movieStore.currentGroupName

        if movieWithContext.addedAt == nil {
            movieWithContext.addedAt = Date()
        }

        if (movieWithContext.addedByName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
           let selectedUser = userStore.selectedUser {
            movieWithContext.addedById = selectedUser.id
            movieWithContext.addedByName = selectedUser.name
        }

        return movieWithContext
    }

    private func metadataMovie(_ existing: Movie, matches candidate: Movie) -> Bool {
        if let existingTMDbId = existing.tmdbId,
           let candidateTMDbId = candidate.tmdbId,
           existingTMDbId == candidateTMDbId {
            return true
        }

        return existing.title.caseInsensitiveCompare(candidate.title) == .orderedSame
            && existing.year == candidate.year
    }
}
