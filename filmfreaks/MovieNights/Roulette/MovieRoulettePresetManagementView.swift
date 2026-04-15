//
//  MovieRoulettePresetManagementView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRoulettePresetManagementView: View {

    let presets: [MovieRoulettePreset]
    let backlogMovies: [Movie]
    let onCreatePreset: (_ name: String, _ movieRefs: [MovieNightMovieRef]) -> Void
    let onUpdatePreset: (_ presetId: UUID, _ name: String, _ movieRefs: [MovieNightMovieRef]) -> Void
    let onDeletePreset: (_ presetId: UUID) -> Void

    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var editingPreset: MovieRoulettePreset?
    @State private var isCreatingPreset: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if presets.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Noch keine Auswahlen")
                                .font(.headline)
                            Text("Lege eine erste vordefinierte Auswahl für diese Gruppe an. Sie kann später direkt im Roulette gewählt werden.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    Section("Auswahlen") {
                        ForEach(presets) { preset in
                            Button {
                                editingPreset = preset
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preset.displayName)
                                            .font(.body.weight(.semibold))
                                        Text(preset.movieCount == 1 ? "1 Film" : "\(preset.movieCount) Filme")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 10)

                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { presets[$0].id }
                            for id in ids {
                                onDeletePreset(id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Auswahlen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingPreset = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(displaySettings.tintColor)
            .sheet(isPresented: $isCreatingPreset) {
                MovieRoulettePresetEditorView(
                    title: "Neue Auswahl",
                    backlogMovies: backlogMovies,
                    initialName: "",
                    initialMovieRefs: [],
                    onSave: onCreatePreset
                )
                .environmentObject(displaySettings)
            }
            .sheet(item: $editingPreset) { preset in
                MovieRoulettePresetEditorView(
                    title: "Auswahl bearbeiten",
                    backlogMovies: backlogMovies,
                    initialName: preset.displayName,
                    initialMovieRefs: preset.movieRefs,
                    onSave: { name, movieRefs in
                        onUpdatePreset(preset.id, name, movieRefs)
                    }
                )
                .environmentObject(displaySettings)
            }
        }
    }
}
