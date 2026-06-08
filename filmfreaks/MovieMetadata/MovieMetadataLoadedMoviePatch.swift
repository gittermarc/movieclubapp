//
//  MovieMetadataLoadedMoviePatch.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieMetadataLoadedMoviePatch: Equatable, Sendable {
    let genres: [String]?
    let genreIds: [Int]?
    let keywords: [String]?
    let keywordIds: [Int]?
    let cast: [CastMember]?
    let directors: [CastMember]?
    let tmdbRating: Double
    let posterPath: String?

    init(details: TMDbMovieDetails) {
        let normalizedGenres = details.genres?
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedKeywords = details.keywords?.allKeywords
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalizedCast = details.credits?.cast
            .prefix(30)
            .map {
                CastMember(
                    personId: $0.id,
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.name.isEmpty }
        let normalizedDirectors = details.credits?.crew
            .filter { ($0.job ?? "").lowercased() == "director" }
            .map {
                CastMember(
                    personId: $0.id,
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.name.isEmpty }
        let mappedGenreIds = details.genres?.map(\.id)
        let mappedKeywordIds = details.keywords?.allKeywords.map(\.id)

        genres = normalizedGenres?.isEmpty == false ? normalizedGenres : nil
        genreIds = mappedGenreIds?.isEmpty == false ? mappedGenreIds : nil
        keywords = normalizedKeywords?.isEmpty == false ? normalizedKeywords : nil
        keywordIds = mappedKeywordIds?.isEmpty == false ? mappedKeywordIds : nil
        cast = normalizedCast?.isEmpty == false ? normalizedCast : nil
        directors = normalizedDirectors?.isEmpty == false ? normalizedDirectors : nil
        tmdbRating = details.vote_average
        posterPath = details.poster_path
    }

    func apply(to movie: inout Movie) {
        if let genres, !genres.isEmpty {
            movie.genres = genres
        }

        if let genreIds, !genreIds.isEmpty {
            movie.genreIds = genreIds
        }

        if let keywords, !keywords.isEmpty {
            movie.keywords = keywords
        }

        if let keywordIds, !keywordIds.isEmpty {
            movie.keywordIds = keywordIds
        }

        if let cast, !cast.isEmpty {
            movie.cast = cast
        }

        if let directors, !directors.isEmpty {
            movie.directors = directors
        }

        movie.tmdbRating = tmdbRating
        if let posterPath {
            movie.posterPath = posterPath
        }
    }

    func applied(to movie: Movie) -> Movie {
        var updatedMovie = movie
        apply(to: &updatedMovie)
        return updatedMovie
    }
}
