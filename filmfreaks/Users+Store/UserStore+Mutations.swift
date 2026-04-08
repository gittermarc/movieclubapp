//
//  UserStore+Mutations.swift
//  filmfreaks
//
//  Split from UserStore.swift
//

import Foundation
internal import SwiftUI

extension UserStore {

    // MARK: - Public mutations

    /// Neuen User für die aktuelle Gruppe anlegen
    func addUser(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // doppelte Namen vermeiden (case-insensitive)
        if users.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return
        }

        let newUser = User(id: UUID(), name: trimmed)
        users.append(newUser)

        if selectedUser == nil {
            selectedUser = newUser
        }

        // Für Gruppen direkt in Cloud spiegeln.
        if let gid = currentGroupId, !gid.isEmpty {
            Task {
                do {
                    try await cloudStore.upsertMember(id: newUser.id, name: trimmed, groupId: gid)
                } catch {
                    print("UserStore: Fehler beim Cloud-upsert Member: \(error)")
                }

                // Optional: nachziehen, damit Reihenfolge/Dedupe mit Cloud konsistent ist.
                await self.refreshFromCloud(force: false)
            }
        }
    }

    /// Löscht User an den übergebenen Indizes
    func deleteUsers(at offsets: IndexSet) {
        let idsToDelete = offsets.map { users[$0].id }
        users.remove(atOffsets: offsets)

        if let selected = selectedUser, !users.contains(selected) {
            selectedUser = users.first
        }

        // Cloud delete
        if let gid = currentGroupId, !gid.isEmpty {
            Task {
                for id in idsToDelete {
                    do {
                        try await cloudStore.deleteMember(id: id, groupId: gid)
                    } catch {
                        print("UserStore: Fehler beim Cloud-delete Member: \(error)")
                    }
                }
                await self.refreshFromCloud(force: false)
            }
        }
    }
}
