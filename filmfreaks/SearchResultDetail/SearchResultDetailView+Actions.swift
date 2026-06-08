//
//  SearchResultDetailView+Actions.swift
//  filmfreaks
//

internal import SwiftUI

extension SearchResultDetailView {

    func selectPerson(personId: Int, name: String, role: String?) {
        selectedPerson = SRSelectedPerson(id: personId, name: name, subtitle: role)
    }

    func createMovie() -> Movie {
        if let details {
            let year = releaseYear(from: details.release_date) ?? "n/a"
            var movie = Movie(
                title: details.title,
                year: year,
                tmdbRating: details.vote_average,
                ratings: [],
                posterPath: details.poster_path,
                watchedDate: nil,
                watchedLocation: nil,
                tmdbId: details.id,
                genres: nil,
                genreIds: nil,
                keywords: nil,
                keywordIds: nil,
                suggestedBy: nil,
                cast: nil,
                directors: nil
            )
            MovieMetadataLoadedMoviePatch(details: details).apply(to: &movie)
            return movie
        }

        let year = releaseYear(from: result.release_date) ?? "n/a"
        return Movie(
            title: result.title,
            year: year,
            tmdbRating: result.vote_average,
            ratings: [],
            posterPath: result.poster_path,
            watchedDate: nil,
            watchedLocation: nil,
            tmdbId: result.id,
            genres: nil,
            genreIds: nil,
            keywords: nil,
            keywordIds: nil,
            suggestedBy: nil,
            cast: nil,
            directors: nil
        )
    }
}
