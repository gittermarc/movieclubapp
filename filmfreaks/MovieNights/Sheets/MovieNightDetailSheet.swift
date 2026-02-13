//
//  MovieNightDetailSheet.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// P2: Detail sheet for a movie night proposal (local only).
struct MovieNightDetailSheet: View {

    let groupId: String
    let eventId: UUID

    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm: Bool = false

    private var event: MovieNightEvent? {
        movieNightStore.events(for: groupId).first(where: { $0.id == eventId })
    }

    private var headerTitle: String {
        guard let e = event else { return "Filmabend" }
        return Self.headerFormatter.string(from: e.proposedStart)
    }

    private var statusText: String {
        guard let e = event else { return "" }
        switch e.status {
        case .open: return "Vorschlag"
        case .scheduled: return "Geplant"
        case .cancelled: return "Abgesagt"
        }
    }

    private var statusSymbol: String {
        guard let e = event else { return "questionmark" }
        switch e.status {
        case .open: return "sparkles"
        case .scheduled: return "checkmark.seal.fill"
        case .cancelled: return "xmark.seal.fill"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let event {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
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
                                    movieNightStore.updateEvent(groupId: groupId, eventId: event.id, status: .open, actorUserId: userStore.selectedUser?.id, actorName: userStore.selectedUser?.name)
                                } label: {
                                    Label("Wieder öffnen", systemImage: "arrow.counterclockwise")
                                }
                            } else {
                                Button {
                                    movieNightStore.updateEvent(groupId: groupId, eventId: event.id, status: .cancelled, actorUserId: userStore.selectedUser?.id, actorName: userStore.selectedUser?.name)
                                } label: {
                                    Label("Absagen", systemImage: "xmark.circle")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                "Vorschlag löschen?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    if let event {
                        movieNightStore.deleteEvent(groupId: groupId, eventId: event.id, actorUserId: userStore.selectedUser?.id, actorName: userStore.selectedUser?.name)
                    }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Vorschlag wird aus der Gruppe entfernt.")
            }
        }
        .tint(displaySettings.tintColor)
    }

    private func headerCard(event: MovieNightEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.title3.weight(.semibold))
                    Text("Vorgeschlagen von \(event.proposerName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    Image(systemName: statusSymbol)
                        .symbolRenderingMode(.hierarchical)
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .circular)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .circular)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(.secondary)
            }

            if let note = normalized(event.note) {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(displaySettings.metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func myResponseCard(event: MovieNightEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deine Antwort")
                .font(.headline)

            if let me = userStore.selectedUser {
                let myDecision = decision(for: me.id)

                HStack(spacing: 10) {
                    decisionButton(title: "Dabei", systemImage: "checkmark", isSelected: myDecision == .accepted) {
                        setDecision(.accepted, for: me, event: event)
                    }

                    decisionButton(title: "Nein", systemImage: "xmark", isSelected: myDecision == .declined) {
                        setDecision(.declined, for: me, event: event)
                    }

                    decisionButton(title: "Offen", systemImage: "hourglass", isSelected: myDecision == .pending) {
                        setDecision(.pending, for: me, event: event)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Kein Nutzer ausgewählt",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Wähle oben in der App einen Nutzer aus.")
                )
                .padding(.top, 4)
            }
        }
        .padding(displaySettings.metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func participantsCard(event: MovieNightEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Teilnehmer")
                .font(.headline)

            if userStore.users.isEmpty {
                Text("Noch keine Nutzer in der Gruppe.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(userStore.users) { user in
                        ParticipantStatusPill(
                            name: user.name,
                            status: statusForPill(userId: user.id)
                        )
                    }
                }
            }
        }
        .padding(displaySettings.metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func statusForPill(userId: UUID) -> ParticipantStatusPill.Status {
        switch decision(for: userId) {
        case .accepted: return .accepted
        case .declined: return .declined
        case .pending: return .pending
        }
    }

    private func decision(for userId: UUID) -> MovieNightResponse.Decision {
        movieNightStore.response(for: groupId, eventId: eventId, userId: userId)?.decision ?? .pending
    }

    private func setDecision(_ decision: MovieNightResponse.Decision, for user: User, event: MovieNightEvent) {
        movieNightStore.setResponse(
            groupId: groupId,
            eventId: event.id,
            userId: user.id,
            userName: user.name,
            decision: decision
        )

        applyAutoStatusIfNeeded(event: event, actor: user)
    }

    private func applyAutoStatusIfNeeded(event: MovieNightEvent, actor: User) {
        // Don't auto-toggle cancelled events.
        if event.status == .cancelled { return }

        let members = userStore.users
        guard !members.isEmpty else { return }

        let responses = members.map { member in
            movieNightStore.response(for: groupId, eventId: event.id, userId: member.id)?.decision ?? .pending
        }

        let anyDeclined = responses.contains(.declined)
        let allAccepted = responses.allSatisfy { $0 == .accepted }

        let next: MovieNightEvent.Status = allAccepted ? .scheduled : .open
        if anyDeclined {
            // Still keep as open to allow re-opening / changing decisions.
            if event.status != .open {
                movieNightStore.updateEvent(groupId: groupId, eventId: event.id, status: .open, actorUserId: userStore.selectedUser?.id, actorName: userStore.selectedUser?.name)
            }
            return
        }

        if event.status != next {
            movieNightStore.updateEvent(groupId: groupId, eventId: event.id, status: next, actorUserId: userStore.selectedUser?.id, actorName: userStore.selectedUser?.name)
        }
    }

    private func decisionButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? displaySettings.tintColor : .secondary)
    }

    private func normalized(_ value: String?) -> String? {
        guard let raw = value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let headerFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEEE, d. MMM · HH:mm")
        return df
    }()
}

#Preview {
    MovieNightDetailSheet(groupId: "", eventId: UUID())
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(DisplaySettings())
}
