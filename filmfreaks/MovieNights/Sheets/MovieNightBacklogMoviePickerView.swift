//
//  MovieNightBacklogMoviePickerView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Full-screen backlog picker (search + quick select).
struct MovieNightBacklogMoviePickerView: View {

    let title: String
    let movies: [Movie]
    @Binding var selection: MovieNightMovieRef?

    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    private var selectedId: UUID? { selection?.movieId }

    private var filteredMovies: [Movie] {
        let base = movies.sorted { lhs, rhs in
            let la = lhs.addedAt ?? .distantPast
            let ra = rhs.addedAt ?? .distantPast
            if la != ra { return la > ra }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }

        return base.filter { movie in
            movie.title.localizedCaseInsensitiveContains(q) ||
            movie.year.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List {
            if selection != nil {
                Section {
                    Button {
                        selection = nil
                        dismiss()
                    } label: {
                        Label("Kein Film auswählen", systemImage: "xmark.circle")
                    }
                }
            }

            Section {
                ForEach(filteredMovies, id: \.id) { movie in
                    MovieNightBacklogMovieRow(
                        movie: movie,
                        isSelected: selectedId == movie.id
                    ) {
                        selection = MovieNightMovieRef(movie: movie)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Backlog durchsuchen")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        .tint(displaySettings.tintColor)
    }
}

private struct MovieNightBacklogMovieRow: View {

    let movie: Movie
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
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

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selection: MovieNightMovieRef? = nil
    let movies = [
        Movie(title: "Arrival", year: "2016", posterPath: nil),
        Movie(title: "Dune", year: "2021", posterPath: nil)
    ]

    NavigationStack {
        MovieNightBacklogMoviePickerView(title: "Backlog", movies: movies, selection: $selection)
            .environmentObject(DisplaySettings())
    }
}
