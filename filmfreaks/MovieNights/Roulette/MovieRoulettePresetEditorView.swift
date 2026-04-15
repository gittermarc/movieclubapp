//
//  MovieRoulettePresetEditorView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRoulettePresetEditorView: View {

    let title: String
    let backlogMovies: [Movie]
    let onSave: (_ name: String, _ movieRefs: [MovieNightMovieRef]) -> Void

    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedMovieRefs: [MovieNightMovieRef]
    @State private var isMoviePickerPresented: Bool = false

    init(
        title: String,
        backlogMovies: [Movie],
        initialName: String,
        initialMovieRefs: [MovieNightMovieRef],
        onSave: @escaping (_ name: String, _ movieRefs: [MovieNightMovieRef]) -> Void
    ) {
        self.title = title
        self.backlogMovies = backlogMovies
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _selectedMovieRefs = State(initialValue: initialMovieRefs)
    }

    private var selectedCountText: String {
        switch selectedMovieRefs.count {
        case 0:
            return "Kein Film ausgewählt"
        case 1:
            return "1 Film ausgewählt"
        default:
            return "\(selectedMovieRefs.count) Filme ausgewählt"
        }
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && !selectedMovieRefs.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("z. B. Sonntagsfilme", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }

                Section {
                    Button {
                        isMoviePickerPresented = true
                    } label: {
                        Label("Filme auswählen", systemImage: "plus.circle")
                    }

                    Text(selectedCountText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Inhalt")
                } footer: {
                    if selectedMovieRefs.isEmpty {
                        Text("Wähle Filme aus dem Backlog der aktiven Gruppe für diese Auswahl aus.")
                    }
                }

                if selectedMovieRefs.isEmpty == false {
                    Section("Ausgewählte Filme") {
                        ForEach(selectedMovieRefs, id: \.movieId) { movieRef in
                            MovieNightSelectedMovieRowView(
                                movie: movieRef,
                                onClear: {
                                    selectedMovieRefs.removeAll { $0.movieId == movieRef.movieId }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(name, selectedMovieRefs)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .tint(displaySettings.tintColor)
            .sheet(isPresented: $isMoviePickerPresented) {
                NavigationStack {
                    MovieRoulettePresetMoviePickerView(
                        movies: backlogMovies,
                        selectedMovieRefs: $selectedMovieRefs
                    )
                    .environmentObject(displaySettings)
                }
            }
        }
    }
}
