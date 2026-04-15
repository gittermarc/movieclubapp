//
//  MovieRoulettePresetMoviePickerView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRoulettePresetMoviePickerView: View {

    let movies: [Movie]
    @Binding var selectedMovieRefs: [MovieNightMovieRef]

    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    private var filteredMovies: [Movie] {
        let sorted = movies.sorted { lhs, rhs in
            let lhsAddedAt = lhs.addedAt ?? .distantPast
            let rhsAddedAt = rhs.addedAt ?? .distantPast
            if lhsAddedAt != rhsAddedAt {
                return lhsAddedAt > rhsAddedAt
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSearch.isEmpty == false else { return sorted }

        return sorted.filter { movie in
            movie.title.localizedCaseInsensitiveContains(trimmedSearch) ||
            movie.year.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filteredMovies, id: \.id) { movie in
                    let movieRef = MovieNightMovieRef(movie: movie)
                    let isSelected = selectedMovieRefs.contains(where: { $0.movieId == movie.id })

                    Button {
                        toggle(movieRef: movieRef)
                    } label: {
                        HStack(spacing: 12) {
                            GoalPosterTileView(movie: movie, size: .init(width: 40, height: 60), cornerRadius: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(movie.title)
                                    .font(.body.weight(.semibold))
                                    .lineLimit(2)

                                Text(movie.year)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 10)

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isSelected ? displaySettings.tintColor : .secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Filme auswählen")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Backlog durchsuchen")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .tint(displaySettings.tintColor)
    }

    private func toggle(movieRef: MovieNightMovieRef) {
        if let index = selectedMovieRefs.firstIndex(where: { $0.movieId == movieRef.movieId }) {
            selectedMovieRefs.remove(at: index)
        } else {
            selectedMovieRefs.append(movieRef)
            selectedMovieRefs = MovieRoulettePreset.deduplicatedMovieRefs(selectedMovieRefs)
        }
    }
}
