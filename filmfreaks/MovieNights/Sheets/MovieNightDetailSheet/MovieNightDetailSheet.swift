//
//  MovieNightDetailSheet.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation
internal import SwiftUI

/// P2: Detail sheet for a movie night proposal (local only).
struct MovieNightDetailSheet: View {

    let groupId: String
    let eventId: UUID

    @EnvironmentObject var movieNightStore: MovieNightStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var groupStore: CloudKitGroupStore
    @EnvironmentObject var displaySettings: DisplaySettings
    @Environment(\.dismiss) var dismiss

    @State var showDeleteConfirm: Bool = false

    var event: MovieNightEvent? {
        movieNightStore.events(for: groupId).first(where: { $0.id == eventId })
    }

    var requiresGroupContext: Bool {
        UUID(uuidString: groupId.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    var isGroupContextReady: Bool {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return false }
        if !requiresGroupContext { return true }
        return GroupContextStore.context(forGroupId: gid) != nil
    }

    var actionsDisabled: Bool {
        requiresGroupContext && !isGroupContextReady
    }

    var body: some View {
        NavigationStack {
            Group {
                if let event {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if requiresGroupContext && !isGroupContextReady {
                                contextNotReadyCard
                            }
                            headerCard(event: event)
                            myResponseCard(event: event)
                            participantsCard(event: event)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    ContentUnavailableView(
                        "Filmabend nicht gefunden",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Der Vorschlag wurde möglicherweise gelöscht.")
                    )
                    .padding()
                }
            }
            .navigationTitle("Filmabend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let event {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Vorschlag löschen", systemImage: "trash")
                            }

                            Divider()

                            if event.status == .cancelled {
                                Button {
                                    setEventStatus(.open, event: event)
                                } label: {
                                    Label("Wieder öffnen", systemImage: "arrow.counterclockwise")
                                }
                            } else {
                                Button {
                                    setEventStatus(.cancelled, event: event)
                                } label: {
                                    Label("Absagen", systemImage: "xmark.circle")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(actionsDisabled)
                }
            }
            .confirmationDialog(
                "Vorschlag löschen?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    if let event {
                        deleteEventAndDismiss(event)
                    } else {
                        dismiss()
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Vorschlag wird aus der Gruppe entfernt.")
            }
        }
        .tint(displaySettings.tintColor)
    }
}

#Preview {
    MovieNightDetailSheet(groupId: "", eventId: UUID())
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(CloudKitGroupStore())
        .environmentObject(DisplaySettings())
}
