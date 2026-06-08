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
        movieStore.addMovie(
            movie,
            to: .watched,
            selectedUser: userStore.selectedUser,
            setsWatchedDateIfMissing: true
        )
    }

    func addMetadataMovieToBacklog(_ movie: Movie) {
        movieStore.addMovie(
            movie,
            to: .backlog,
            selectedUser: userStore.selectedUser
        )
    }
}
