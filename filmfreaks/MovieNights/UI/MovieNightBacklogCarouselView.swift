//
//  MovieNightBacklogCarouselView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Horizontally scrolling backlog preview used in the proposal sheet.
struct MovieNightBacklogCarouselView: View {

    let movies: [Movie]
    @Binding var selection: MovieNightMovieRef?

    private var selectedId: UUID? { selection?.movieId }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(movies, id: \.id) { movie in
                    MovieNightBacklogPosterButton(
                        movie: movie,
                        isSelected: selectedId == movie.id
                    ) {
                        selection = MovieNightMovieRef(movie: movie)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Backlog Vorschau")
    }
}

private struct MovieNightBacklogPosterButton: View {

    let movie: Movie
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            ZStack(alignment: .topTrailing) {
                GoalPosterTileView(movie: movie, size: .init(width: 78, height: 117), cornerRadius: 14)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.large)
                        .foregroundStyle(.primary)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(movie.title)
        .accessibilityHint(isSelected ? "Ausgewählt" : "Antippen zum Auswählen")
    }
}

#Preview {
    @Previewable @State var selection: MovieNightMovieRef? = nil
    let movies = [
        Movie(title: "Dune", year: "2021", posterPath: nil),
        Movie(title: "Arrival", year: "2016", posterPath: nil),
        Movie(title: "Blade Runner 2049", year: "2017", posterPath: nil)
    ]

    MovieNightBacklogCarouselView(movies: movies, selection: $selection)
        .padding()
}
