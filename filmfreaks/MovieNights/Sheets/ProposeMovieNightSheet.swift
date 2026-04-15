//
//  ProposeMovieNightSheet.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation
internal import SwiftUI

/// P2: Create a new movie night proposal (local only).
struct ProposeMovieNightSheet: View {

    let groupId: String
    let initialDate: Date

    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var proposedStart: Date
    @State private var note: String
    @State private var suggestedMovie: MovieNightMovieRef?
    @State private var showNoUserAlert: Bool = false

    private var isGroupContextReady: Bool {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return false }
        // UUID groupId => sehr wahrscheinlich Sharing/Zone Gruppe.
        if UUID(uuidString: gid) == nil { return true }
        return GroupContextStore.context(forGroupId: gid) != nil
    }

    init(groupId: String, initialDate: Date, initialSuggestedMovie: MovieNightMovieRef? = nil) {
        self.groupId = groupId
        self.initialDate = initialDate
        _proposedStart = State(initialValue: initialDate)
        _note = State(initialValue: "")
        _suggestedMovie = State(initialValue: initialSuggestedMovie)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let suggestedMovie {
                        MovieNightSelectedMovieRowView(movie: suggestedMovie) {
                            self.suggestedMovie = nil
                        }
                    } else {
                        HStack {
                            Image(systemName: "film")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)

                            Text("Kein Film ausgewählt")
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 10)

                            Text("Optional")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if backlogMovies.isEmpty {
                        Text("Backlog ist leer – füg erst einen Film hinzu, dann kannst du ihn hier auswählen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        MovieNightBacklogCarouselView(movies: previewBacklogMovies, selection: $suggestedMovie)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }

                    NavigationLink {
                        MovieNightBacklogMoviePickerView(
                            title: "Backlog",
                            movies: backlogMovies,
                            selection: $suggestedMovie
                        )
                    } label: {
                        Label("Alle Backlog-Filme", systemImage: "film.stack")
                    }
                    .disabled(backlogMovies.isEmpty)
                } header: {
                    Text("Film")
                } footer: {
                    Text("Tipp: Du kannst auch ohne Film vorschlagen – der Filmabend ist dann einfach nur ein Termin.")
                }

                Section {
                    DatePicker(
                        "Start",
                        selection: $proposedStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                } header: {
                    Text("Wann?")
                }

                Section {
                    TextField("Optional: Notiz", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notiz")
                } footer: {
                    Text("Du kannst z.B. Uhrzeit, Ort oder Themenwünsche rein schreiben.")
                }

                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)

                        Text("Vorschlag von")
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 10)

                        Text(userStore.selectedUser?.name ?? "—")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .navigationTitle("Filmabend vorschlagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Vorschlagen") { propose() }
                        .font(.body.weight(.semibold))
                        .disabled(userStore.selectedUser == nil || !isGroupContextReady)
                }
            }
            .alert(
                "Kein Nutzer ausgewählt",
                isPresented: $showNoUserAlert,
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    Text("Bitte wähle erst oben in der App einen Nutzer aus.")
                }
            )
        }
        .tint(displaySettings.tintColor)
    }

    private var backlogMovies: [Movie] {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = movieStore.currentGroupId?.trimmingCharacters(in: .whitespacesAndNewlines)

        return movieStore.backlogMovies.filter { movie in
            if let mid = movie.groupId, !mid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return mid == gid
            }

            // Legacy movies without groupId: only surface them when the user is currently on the same group.
            return current == gid
        }
    }

    private var previewBacklogMovies: [Movie] {
        let sorted = backlogMovies.sorted { lhs, rhs in
            let la = lhs.addedAt ?? .distantPast
            let ra = rhs.addedAt ?? .distantPast
            if la != ra { return la > ra }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return Array(sorted.prefix(20))
    }

    private func propose() {
        guard let user = userStore.selectedUser else {
            showNoUserAlert = true
            return
        }

        guard isGroupContextReady else {
            return
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote: String? = trimmed.isEmpty ? nil : trimmed

        _ = movieNightStore.proposeEvent(
            groupId: groupId,
            proposedStart: proposedStart,
            suggestedMovie: suggestedMovie,
            note: finalNote,
            proposerUserId: user.id,
            proposerName: user.name
        )

        dismiss()
    }
}

#Preview {
    ProposeMovieNightSheet(groupId: "", initialDate: .now)
        .environmentObject(MovieStore(useCloud: false))
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(DisplaySettings())
}
