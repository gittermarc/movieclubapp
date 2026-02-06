//
//  GoalMoviePosterNavTile.swift
//  filmfreaks
//

internal import SwiftUI

/// Poster tile that navigates to `MovieDetailView` when the movie exists in the current `MovieStore`.
struct GoalMoviePosterNavTile: View {

    let movie: Movie
    var size: CGSize = .init(width: 60, height: 90)
    var cornerRadius: CGFloat = 10

    @EnvironmentObject var movieStore: MovieStore

    var body: some View {
        if let idx = movieStore.movies.firstIndex(where: { $0.id == movie.id }) {
            NavigationLink {
                MovieDetailView(
                    movie: $movieStore.movies[idx],
                    isBacklog: false
                )
            } label: {
                GoalPosterTileView(movie: movie, size: size, cornerRadius: cornerRadius)
            }
            .buttonStyle(.plain)
        } else {
            GoalPosterTileView(movie: movie, size: size, cornerRadius: cornerRadius)
        }
    }
}
