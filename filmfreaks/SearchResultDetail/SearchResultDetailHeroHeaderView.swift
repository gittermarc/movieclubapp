//
//  SearchResultDetailHeroHeaderView.swift
//  filmfreaks
//
//  Compatibility wrapper around the shared metadata hero.
//

internal import SwiftUI

struct SearchResultDetailHeroHeaderView: View {
    let posterPath: String?
    let posterURL: URL?
    let title: String
    let yearText: String?
    let tmdbRating: Double
    var backdropURL: URL? = nil
    var runtimeText: String? = nil
    var certificationText: String? = nil

    var body: some View {
        MovieMetadataHeroHeaderView(
            posterURL: posterURL,
            backdropURL: backdropURL,
            posterFallbackBackgroundURL: MovieMetadataPresentation.posterURL(path: posterPath, width: .w342),
            title: title,
            yearText: yearText,
            tmdbRating: tmdbRating,
            groupRating: nil,
            runtimeText: runtimeText,
            certificationText: certificationText
        )
    }
}
