//
//  MovieDetailHeroHeaderView.swift
//  filmfreaks
//
//  Compatibility wrapper around the shared metadata hero.
//

internal import SwiftUI

struct MovieDetailHeroHeaderView: View {
    let movie: Movie
    var backdropURL: URL? = nil
    var runtimeText: String? = nil
    var certificationText: String? = nil
    var groupRating: Double? = nil

    var body: some View {
        MovieMetadataHeroHeaderView(
            posterURL: movie.posterURL,
            backdropURL: backdropURL,
            posterFallbackBackgroundURL: MovieMetadataPresentation.posterURL(path: movie.posterPath, width: .w342),
            title: movie.title,
            yearText: movie.year,
            tmdbRating: movie.tmdbRating,
            groupRating: groupRating,
            runtimeText: runtimeText,
            certificationText: certificationText
        )
    }
}
