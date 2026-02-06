//
//  MovieSearchMapper.swift
//  filmfreaks
//

import Foundation

/// Gemeinsame Helper für MovieSearch: Year-Parsing, Keys (Dedup/Presence) und Mapping.
enum MovieSearchMapper {

    static func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }

    static func yearInt(from dateString: String?) -> Int? {
        guard let y = releaseYear(from: dateString) else { return nil }
        return Int(y)
    }

    /// Schlüssel, um konsistent zu erkennen, ob ein Film schon in einer Liste ist.
    static func key(for movie: Movie) -> String {
        movie.title.lowercased() + "|" + movie.year
    }

    static func key(for result: TMDbMovieResult) -> String {
        let year = releaseYear(from: result.release_date) ?? "n/a"
        return result.title.lowercased() + "|" + year
    }

    static func convertToMovie(_ result: TMDbMovieResult) -> Movie {
        let year = releaseYear(from: result.release_date) ?? "n/a"
        return Movie(
            title: result.title,
            year: year,
            tmdbRating: result.vote_average,
            ratings: [],
            posterPath: result.poster_path,
            tmdbId: result.id
        )
    }
}
