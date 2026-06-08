//
//  SearchResultDetailView+MetadataActions.swift
//  filmfreaks
//

internal import SwiftUI

extension SearchResultDetailView {
    func openMetadataDetail(_ result: TMDbMovieResult) {
        metadataDetailResult = result
    }

    func addMetadataResultToBacklog(_ result: TMDbMovieResult) {
        addMetadataMovieToBacklog(MovieSearchMapper.convertToMovie(result))
    }

    func addMetadataMovieToWatched(_ movie: Movie) {
        let matches: (Movie) -> Bool = { existing in
            metadataMovie(existing, matches: movie)
        }

        if !localWatchedMovies.contains(where: matches) {
            localWatchedMovies.append(movie)
        }
        localBacklogMovies.removeAll(where: matches)

        if metadataMovie(movie, matches: createMovie()) {
            isInWatched = true
            isInBacklog = false
        }

        onAddToWatched(movie)
    }

    func addMetadataMovieToBacklog(_ movie: Movie) {
        let matches: (Movie) -> Bool = { existing in
            metadataMovie(existing, matches: movie)
        }

        guard !localWatchedMovies.contains(where: matches) else { return }

        if !localBacklogMovies.contains(where: matches) {
            localBacklogMovies.append(movie)
        }

        if metadataMovie(movie, matches: createMovie()) {
            isInBacklog = true
        }

        onAddToBacklog(movie)
    }

    private func metadataMovie(_ existing: Movie, matches candidate: Movie) -> Bool {
        MovieStore.metadataMovie(existing, matches: candidate)
    }
}
