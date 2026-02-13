//
//  MovieNightSelectedMovieRowView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Compact row that shows the currently selected movie for a proposal.
struct MovieNightSelectedMovieRowView: View {

    let movie: MovieNightMovieRef
    var onClear: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            GoalPosterTileView(posterURL: movie.posterURL, size: .init(width: 44, height: 66), cornerRadius: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)

                Text(movie.year)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            if let onClear {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filmauswahl entfernen")
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MovieNightSelectedMovieRowView(
        movie: MovieNightMovieRef(
            movieId: UUID(),
            title: "The Big Lebowski",
            year: "1998",
            posterPath: nil,
            tmdbId: nil
        ),
        onClear: {}
    )
}
