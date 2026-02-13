//
//  ProposeMovieNightSheet.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// P2: Create a new movie night proposal (local only).
struct ProposeMovieNightSheet: View {

    let groupId: String
    let initialDate: Date

    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var proposedStart: Date
    @State private var note: String
    @State private var showNoUserAlert: Bool = false

    init(groupId: String, initialDate: Date) {
        self.groupId = groupId
        self.initialDate = initialDate
        _proposedStart = State(initialValue: initialDate)
        _note = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
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

    private func propose() {
        guard let user = userStore.selectedUser else {
            showNoUserAlert = true
            return
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote: String? = trimmed.isEmpty ? nil : trimmed

        _ = movieNightStore.proposeEvent(
            groupId: groupId,
            proposedStart: proposedStart,
            note: finalNote,
            proposerUserId: user.id,
            proposerName: user.name
        )

        dismiss()
    }
}

#Preview {
    ProposeMovieNightSheet(groupId: "", initialDate: .now)
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(DisplaySettings())
}
