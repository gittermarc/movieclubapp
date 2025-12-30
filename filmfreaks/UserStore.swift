//
//  UserStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
import Combine
import CryptoKit
internal import SwiftUI

@MainActor
class UserStore: ObservableObject {

    // MARK: - Public state

    @Published var users: [User] = [] {
        didSet {
            if isApplyingCloudUpdate { return }
            saveUsers()
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
        self.users = Self.loadUsers(forGroupId: groupIdFromDefaults)

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
        self.users = Self.loadUsers(forGroupId: groupId)

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
            let names = try await cloudStore.fetchMembers(forGroupId: gid)

            if !names.isEmpty {
                applyCloudUsers(names: names, groupId: gid)
            } else {
                // Cloud leer → falls lokal bereits Users existieren, als „Initial-Seed“ hochladen.
                // (So hat der Gruppenersteller sofort Members in der Cloud.)
                if !users.isEmpty {
                    for u in users {
                        do { try await cloudStore.upsertMember(name: u.name, groupId: gid) }
                        catch { print("CloudKitUserStore upsert bootstrap error: \(error)") }
                    }

                    let names2 = try await cloudStore.fetchMembers(forGroupId: gid)
                    if !names2.isEmpty {
                        applyCloudUsers(names: names2, groupId: gid)
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

        // doppelte Namen vermeiden
        if users.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return
        }

        let newUser = makeUser(name: trimmed, groupId: currentGroupId)
        users.append(newUser)

        if selectedUser == nil {
            selectedUser = newUser
        }

        // Für Gruppen direkt in Cloud spiegeln.
        if let gid = currentGroupId, !gid.isEmpty {
            Task {
                do { try await cloudStore.upsertMember(name: trimmed, groupId: gid) }
                catch { print("UserStore: Fehler beim Cloud-upsert Member: \(error)") }

                // Optional: nachziehen, damit Reihenfolge/Dedupe mit Cloud konsistent ist.
                await self.refreshFromCloud(force: false)
            }
        }
    }

    /// Löscht User an den übergebenen Indizes
    func deleteUsers(at offsets: IndexSet) {
        let namesToDelete = offsets.map { users[$0].name }
        users.remove(atOffsets: offsets)

        if let selected = selectedUser, !users.contains(selected) {
            selectedUser = users.first
        }

        // Cloud delete
        if let gid = currentGroupId, !gid.isEmpty {
            Task {
                for name in namesToDelete {
                    do { try await cloudStore.deleteMember(name: name, groupId: gid) }
                    catch { print("UserStore: Fehler beim Cloud-delete Member: \(error)") }
                }
                await self.refreshFromCloud(force: false)
            }
        }
    }

    // MARK: - Cloud apply

    private func applyCloudUsers(names: [String], groupId: String) {
        let previousSelectedName = selectedUser?.name

        let cloudUsers: [User] = names
            .map { makeUser(name: $0, groupId: groupId) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        isApplyingCloudUpdate = true
        users = cloudUsers
        isApplyingCloudUpdate = false

        if let prev = previousSelectedName,
           let match = users.first(where: { $0.name.caseInsensitiveCompare(prev) == .orderedSame }) {
            selectedUser = match
        } else {
            selectedUser = users.first
        }
    }

    // MARK: - Stabile User-IDs (ohne User.swift zu ändern)

    private func makeUser(name: String, groupId: String?) -> User {
        var user = User(name: name)
        if let gid = groupId, !gid.isEmpty {
            user.id = deterministicUUID(forName: name, groupId: gid)
        }
        return user
    }

    private func deterministicUUID(forName name: String, groupId: String) -> UUID {
        let canonicalName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let canonicalGroup = groupId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let seed = "\(canonicalGroup)|\(canonicalName)"
        let hash = SHA256.hash(data: Data(seed.utf8))
        let bytes = Array(hash)

        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }

    // MARK: - Persistenz

    private func storageKey(for groupId: String?) -> String {
        if let id = groupId, !id.isEmpty {
            return "Users_\(id)"
        } else {
            return "Users_Default"
        }
    }

    private func saveUsers() {
        let key = storageKey(for: currentGroupId)
        do {
            let data = try JSONEncoder().encode(users)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("UserStore: Fehler beim Speichern der Users für Key \(key): \(error)")
        }
    }

    private static func loadUsers(forGroupId groupId: String?) -> [User] {
        let key: String
        if let id = groupId, !id.isEmpty {
            key = "Users_\(id)"
        } else {
            key = "Users_Default"
        }

        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([User].self, from: data)
            return decoded
        } catch {
            print("UserStore: Fehler beim Laden der Users für Key \(key): \(error)")
            return []
        }
    }
}
