//
//  MovieNightDetailSheet+Responses.swift
//  filmfreaks
//
//  P0.3: split out response + participant UI.
//

import Foundation
internal import SwiftUI

extension MovieNightDetailSheet {

    func myResponseCard(event: MovieNightEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Deine Antwort")
                .font(.headline)

            if requiresGroupContext && !isGroupContextReady {
                Text("Gruppe wird noch geladen – bitte kurz warten oder neu laden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Neu laden") {
                    reloadGroupContextAndNightData()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if let me = userStore.selectedUser {
                let myDecision = decision(for: me.id)

                HStack(spacing: 10) {
                    decisionButton(title: "Dabei", systemImage: "checkmark", isSelected: myDecision == .accepted) {
                        setDecision(.accepted, for: me, event: event)
                    }
                    .disabled(requiresGroupContext && !isGroupContextReady)

                    decisionButton(title: "Nein", systemImage: "xmark", isSelected: myDecision == .declined) {
                        setDecision(.declined, for: me, event: event)
                    }
                    .disabled(requiresGroupContext && !isGroupContextReady)

                    decisionButton(title: "Offen", systemImage: "hourglass", isSelected: myDecision == .pending) {
                        setDecision(.pending, for: me, event: event)
                    }
                    .disabled(requiresGroupContext && !isGroupContextReady)
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

    func participantsCard(event: MovieNightEvent) -> some View {
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

    func statusForPill(userId: UUID) -> ParticipantStatusPill.Status {
        switch decision(for: userId) {
        case .accepted: return .accepted
        case .declined: return .declined
        case .pending: return .pending
        }
    }

    func decision(for userId: UUID) -> MovieNightResponse.Decision {
        movieNightStore.response(for: groupId, eventId: eventId, userId: userId)?.decision ?? .pending
    }

    func setDecision(_ decision: MovieNightResponse.Decision, for user: User, event: MovieNightEvent) {
        movieNightStore.setResponse(
            groupId: groupId,
            eventId: event.id,
            userId: user.id,
            userName: user.name,
            decision: decision
        )

        applyAutoStatusIfNeeded(event: event, actor: user)
    }

    func applyAutoStatusIfNeeded(event: MovieNightEvent, actor: User) {
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
                setEventStatus(.open, event: event)
            }
            return
        }

        if event.status != next {
            setEventStatus(next, event: event)
        }
    }

    func decisionButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
}
