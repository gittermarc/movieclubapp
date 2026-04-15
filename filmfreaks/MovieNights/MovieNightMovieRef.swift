//
//  MovieNightMovieRef.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// Lightweight snapshot of a movie chosen for a movie night proposal.
///
/// We store a snapshot (title/year/poster) so proposals still look good even
/// when the original movie is removed from the backlog later.
nonisolated struct MovieNightMovieRef: Codable, Hashable {
    var movieId: UUID
    var title: String
    var year: String
    var posterPath: String?
    var tmdbId: Int?

    init(movieId: UUID, title: String, year: String, posterPath: String?, tmdbId: Int?) {
        self.movieId = movieId
        self.title = title
        self.year = year
        self.posterPath = posterPath
        self.tmdbId = tmdbId
    }

    init(movie: Movie) {
        self.movieId = movie.id
        self.title = movie.title
        self.year = movie.year
        self.posterPath = movie.posterPath
        self.tmdbId = movie.tmdbId
    }
}

extension MovieNightMovieRef {
    nonisolated var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
}
