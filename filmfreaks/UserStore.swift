//
//  UserStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
import Combine
internal import SwiftUI

@MainActor
class UserStore: ObservableObject {

    // MARK: - Public state

    @Published var users: [User] = [] {
        didSet {
            if isApplyingCloudUpdate { return }
            PersistenceManager.shared.saveUsers(users, groupId: currentGroupId)
        }
    }

    /// Wer gerade bewertet etc.
    @Published var selectedUser: User?

    /// Wird gesetzt, während wir Members aus iCloud laden oder Änderungen pushen.
    @Published var isSyncing: Bool = false

    // MARK: - Private state

    /// Zu welcher Gruppe gehören diese `users`?
    private var currentGroupId: String?

    /// CloudKit-Backend (Members).
    private let cloudStore = CloudKitUserStore()

    /// Verhindert didSet-Schleifen beim Cloud-Apply.
    private var isApplyingCloudUpdate: Bool = false

    /// Throttle gegen „zu viele“ Fetches (z.B. App wird aktiv + Pull-to-refresh kurz hintereinander).
    private var lastRefreshAt: Date?
    private let minRefreshInterval: TimeInterval = 8

    // MARK: - Init

    init() {
        // gleiche Group-ID wie MovieStore verwenden
        let groupIdFromDefaults = UserDefaults.standard.string(forKey: "CurrentGroupId")
        self.currentGroupId = groupIdFromDefaults
        self.users = PersistenceManager.shared.loadUsers(groupId: groupIdFromDefaults)

        if let first = users.first {
            self.selectedUser = first
        } else {
            self.selectedUser = nil
        }

        // Falls wir direkt in einer Gruppe sind: Members aus iCloud nachladen.
        if let gid = groupIdFromDefaults, !gid.isEmpty {
            Task { await self.refreshFromCloud(force: true) }
        }
    }

    // MARK: - Öffentliche API

    /// Wird aufgerufen, wenn die Gruppe wechselt (neue Gruppe / join / wechseln)
    func loadUsers(forGroupId groupId: String?) {
        self.currentGroupId = groupId

        // Erst lokal laden (schnelle UI), dann Cloud (Autorität für Gruppen).
        self.users = PersistenceManager.shared.loadUsers(groupId: groupId)

        if let first = users.first {
            self.selectedUser = first
        } else {
            self.selectedUser = nil
        }

        // Für Gruppen: direkt Cloud-Fetch.
        if let gid = groupId, !gid.isEmpty {
            Task { await self.refreshFromCloud(force: true) }
        }
    }

    /// Manuelles Refresh (z.B. Pull-to-refresh oder App-Resume)
    func refreshFromCloud(force: Bool = false) async {
        guard let gid = currentGroupId, !gid.isEmpty else {
            // Standard-/Offline-Gruppe bleibt lokal.
            return
        }

        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshAt = Date()

        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let members = try await cloudStore.fetchMembers(forGroupId: gid)

            if !members.isEmpty {
                applyCloudUsers(members: members, groupId: gid)
            } else {
                // Cloud leer → falls lokal bereits Users existieren, als „Initial-Seed“ hochladen.
                // (So hat der Gruppenersteller sofort Members in der Cloud.)
                if !users.isEmpty {
                    for u in users {
                        do { try await cloudStore.upsertMember(id: u.id, name: u.name, groupId: gid) }
                        catch { print("CloudKitUserStore upsert bootstrap error: \(error)") }
                    }

                    let members2 = try await cloudStore.fetchMembers(forGroupId: gid)
                    if !members2.isEmpty {
                        applyCloudUsers(members: members2, groupId: gid)
                    }
                }
            }
        } catch {
            print("UserStore: Fehler beim Laden aus CloudKit: \(error)")
        }
    }

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
                do { try await cloudStore.upsertMember(id: newUser.id, name: trimmed, groupId: gid) }
                catch { print("UserStore: Fehler beim Cloud-upsert Member: \(error)") }

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
                    do { try await cloudStore.deleteMember(id: id, groupId: gid) }
                    catch { print("UserStore: Fehler beim Cloud-delete Member: \(error)") }
                }
                await self.refreshFromCloud(force: false)
            }
        }
    }

    // MARK: - Cloud apply

    private func applyCloudUsers(members: [CloudKitUserStore.CloudMember], groupId: String) {
        let previousSelectedId = selectedUser?.id
        let previousSelectedName = selectedUser?.name

        let cloudUsers: [User] = members
            .map { User(id: $0.id, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        isApplyingCloudUpdate = true
        users = cloudUsers
        isApplyingCloudUpdate = false

        if let prevId = previousSelectedId,
           let match = users.first(where: { $0.id == prevId }) {
            selectedUser = match
        } else if let prevName = previousSelectedName,
                  let match = users.first(where: { $0.name.caseInsensitiveCompare(prevName) == .orderedSame }) {
            selectedUser = match
        } else {
            selectedUser = users.first
        }
    }

}
