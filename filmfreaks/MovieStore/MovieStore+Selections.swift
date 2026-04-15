//
//  MovieStore+Selections.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

import Foundation

internal extension MovieStore {

    // MARK: - Published didSet handlers

    func handleCurrentGroupIdDidSet() {
        UserDefaults.standard.set(currentGroupId, forKey: "CurrentGroupId")
        addOrUpdateCurrentGroupInKnownGroups()

        // Load per-group sync meta (pending, last sync, last error)
        loadSyncMetaForCurrentGroup()
    }

    func handleCurrentGroupNameDidSet() {
        UserDefaults.standard.set(currentGroupName, forKey: "CurrentGroupName")
        addOrUpdateCurrentGroupInKnownGroups()
    }

    // MARK: - Gruppen API

    func createNewGroup(withName name: String) {
        let newId = UUID().uuidString

        currentGroupId = newId
        currentGroupName = name

        // Neue Gruppe startet leer – wir laden trotzdem den lokalen Cache,
        // damit die Persistenz group-scoped sauber greift.
        loadLocalCache(for: newId)

        print("MovieStore: created NEW EMPTY group '\(name)' with id \(newId)")

        addOrUpdateCurrentGroupInKnownGroups()
    }

    func joinGroup(withInviteCode code: String) {
        currentGroupId = code
        currentGroupName = currentGroupName

        // Erst lokal (schnell), danach Cloud (Autorität)
        loadLocalCache(for: code)

        addOrUpdateCurrentGroupInKnownGroups()

        Task { await self.loadFromCloud() }
    }

    /// Aktiviert eine CloudKit-Sharing Gruppe (private/shared DB) als aktuelle Gruppe.
    func activateCloudGroup(_ group: GroupContext) {
        currentGroupId = group.id
        currentGroupName = group.name

        // Erst lokal (schnell), danach Cloud (Autorität)
        loadLocalCache(for: group.id)
        addOrUpdateCurrentGroupInKnownGroups()

        Task { await self.loadFromCloud() }
    }

    func leaveCurrentGroup() {
        guard let oldId = currentGroupId else { return }

        print("MovieStore: leaving group with id \(oldId)")

        knownGroups.removeAll { $0.id == oldId }
        activateLocalGroup()
    }

    func activateLocalGroup() {
        currentGroupId = nil
        currentGroupName = nil

        // Fallback auf die lokale Standardgruppe – danach (best effort) Cloud-Reload.
        loadLocalCache(for: nil)

        Task { await self.loadFromCloud() }
    }

    func addOrUpdateCurrentGroupInKnownGroups() {
        guard let id = currentGroupId else { return }

        if let index = knownGroups.firstIndex(where: { $0.id == id }) {
            if let name = currentGroupName, !name.isEmpty, knownGroups[index].name != name {
                knownGroups[index].name = name
            }
        } else {
            let info = GroupInfo(id: id, name: currentGroupName)
            knownGroups.append(info)
        }
    }

    // MARK: - bekannte Gruppen verwalten

    func saveKnownGroups() {
        if let data = try? JSONEncoder().encode(knownGroups) {
            UserDefaults.standard.set(data, forKey: Self.knownGroupsKey)
        }
    }

    static func loadKnownGroups() -> [GroupInfo] {
        guard let data = UserDefaults.standard.data(forKey: knownGroupsKey),
              let decoded = try? JSONDecoder().decode([GroupInfo].self, from: data) else {
            return []
        }
        return decoded
    }
}

private extension MovieStore {
    private static let knownGroupsKey = "KnownGroups"

    func loadLocalCache(for groupId: String?) {
        isApplyingCloudUpdate = true
        movies = PersistenceManager.shared.loadMovies(groupId: groupId)
        backlogMovies = PersistenceManager.shared.loadBacklogMovies(groupId: groupId)
        isApplyingCloudUpdate = false
    }

}
