//
//  GroupShareSheetView.swift
//  filmfreaks
//
//  Shows the system CloudKit sharing UI plus a small, always-visible summary
//  of already invited people (participants) so users can remember who they invited.
//

internal import SwiftUI
import Foundation
import CloudKit

struct GroupShareSheetView: View {
    let container: CKContainer
    @Binding var share: CKShare

    @State private var isExpanded = false
    @State private var lastErrorMessage: String?

    var body: some View {
        CloudSharingControllerView(
            container: container,
            share: $share,
            onError: { error in
                lastErrorMessage = error.localizedDescription
            }
        )
        .ignoresSafeArea()
        .task {
            // Make sure we start with the latest participant list (e.g. when reopening the sheet later).
            do {
                let fetched = try await container.privateCloudDatabase.record(for: share.recordID)
                if let fetchedShare = fetched as? CKShare {
                    share = fetchedShare
                }
            } catch {
                // Ignore refresh errors; the system UI can still create/share.
            }
        }
        .safeAreaInset(edge: .bottom) {
            ShareParticipantsCard(share: share, isExpanded: $isExpanded)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .alert(
            "Teilen fehlgeschlagen",
            isPresented: Binding(
                get: { lastErrorMessage != nil },
                set: { if !$0 { lastErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lastErrorMessage ?? "")
        }
    }
}

private struct ShareParticipantsCard: View {
    let share: CKShare
    @Binding var isExpanded: Bool

    private var invited: [CKShare.Participant] {
        // Treat these as optionals so conditional binding works across SDK variants.
        let owner: CKShare.Participant? = share.owner
        let current: CKShare.Participant? = share.currentUserParticipant

        return share.participants.filter { p in
            if let owner, p === owner { return false }
            if let current, p === current { return false }
            return true
        }
    }

    private var invitedSummary: String {
        guard !invited.isEmpty else { return "Noch niemand eingeladen." }
        let names = invited.map { displayName(for: $0) }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "person.2")
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Eingeladene Personen")
                        .font(.subheadline.weight(.semibold))

                    Text(invitedSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? 2 : 1)
                }

                Spacer(minLength: 8)

                Text("\(invited.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.thinMaterial)
                    .clipShape(Capsule())

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Liste einklappen" : "Liste ausklappen")
            }

            if isExpanded {
                if invited.isEmpty {
                    Text("Noch niemand eingeladen – nutz einfach die Freigabe-Optionen darüber.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(invitedItems) { item in
                                ShareParticipantRow(participant: item.participant)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private struct ParticipantItem: Identifiable {
        let id: ObjectIdentifier
        let participant: CKShare.Participant
    }

    private var invitedItems: [ParticipantItem] {
        invited.map { ParticipantItem(id: ObjectIdentifier($0), participant: $0) }
    }

    private func displayName(for participant: CKShare.Participant) -> String {
        if let comps = participant.userIdentity.nameComponents {
            let formatted = PersonNameComponentsFormatter()
                .string(from: comps)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !formatted.isEmpty { return formatted }
        }

        // lookupInfo can be empty depending on discoverability settings.
        if let email = participant.userIdentity.lookupInfo?.emailAddress, !email.isEmpty {
            return email
        }
        if let phone = participant.userIdentity.lookupInfo?.phoneNumber, !phone.isEmpty {
            return phone
        }

        if let recordName = participant.userIdentity.userRecordID?.recordName, !recordName.isEmpty {
            let suffix = recordName.suffix(6)
            return "iCloud Nutzer …\(suffix)"
        }

        return "Unbekannter Nutzer"
    }
}

private struct ShareParticipantRow: View {
    let participant: CKShare.Participant

    private var name: String {
        if let comps = participant.userIdentity.nameComponents {
            let formatted = PersonNameComponentsFormatter()
                .string(from: comps)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !formatted.isEmpty { return formatted }
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress, !email.isEmpty {
            return email
        }
        if let phone = participant.userIdentity.lookupInfo?.phoneNumber, !phone.isEmpty {
            return phone
        }
        if let recordName = participant.userIdentity.userRecordID?.recordName, !recordName.isEmpty {
            return "iCloud Nutzer …\(recordName.suffix(6))"
        }
        return "Unbekannter Nutzer"
    }

    private var statusText: String {
        switch participant.acceptanceStatus {
        case .accepted:
            return "Akzeptiert"
        case .pending:
            return "Ausstehend"
        case .removed:
            return "Entfernt"
        case .unknown:
            return "Unbekannt"
        @unknown default:
            return "Unbekannt"
        }
    }

    private var permissionText: String {
        switch participant.permission {
        case .readOnly:
            return "Nur lesen"
        case .readWrite:
            return "Lesen & Schreiben"
        case .none:
            return "Keine Rechte"
        case .unknown:
            return "—"
        @unknown default:
            return "—"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text("\(statusText) • \(permissionText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var statusIcon: String {
        switch participant.acceptanceStatus {
        case .accepted:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .removed:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }
}
