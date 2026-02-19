//
//  MovieStore+Persistence.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

import Foundation

internal extension MovieStore {

    // MARK: - Published didSet handlers

    func handleMoviesDidSet(oldValue: [Movie]) {
        if isApplyingCloudUpdate { return }

        // Cheaper than JSON encoding (and avoids doing work twice).
        if oldValue == movies { return }

        PersistenceManager.shared.saveMovies(movies, groupId: currentGroupId)

        if cloudStore != nil {
            enqueueCloudSync(newList: movies, oldList: oldValue, isBacklog: false)
        }
    }

    func handleBacklogMoviesDidSet(oldValue: [Movie]) {
        if isApplyingCloudUpdate { return }

        if oldValue == backlogMovies { return }

        PersistenceManager.shared.saveBacklogMovies(backlogMovies, groupId: currentGroupId)

        if cloudStore != nil {
            enqueueCloudSync(newList: backlogMovies, oldList: oldValue, isBacklog: true)
        }
    }

    // MARK: - Sync meta persistence (per group)

    func groupKey(_ groupId: String?) -> String {
        let gid = (groupId ?? currentGroupId)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return gid.isEmpty ? "__default__" : gid
    }

    func loadSyncMetaForCurrentGroup() {
        let gid = currentGroupId
        let defaults = UserDefaults.standard
        pendingCloudChangesCount = defaults.integer(forKey: syncKey("pendingCount", groupId: gid))
        lastCloudSyncAt = defaults.object(forKey: syncKey("lastSyncAt", groupId: gid)) as? Date
        lastCloudSyncError = defaults.string(forKey: syncKey("lastError", groupId: gid))
    }

    func applyPendingCount(_ count: Int, forGroupId groupId: String?) {
        let defaults = UserDefaults.standard

        // Persist per group, but only update UI if this is the active group.
        defaults.set(count, forKey: syncKey("pendingCount", groupId: groupId))

        if groupKey(groupId) == groupKey(currentGroupId) {
            pendingCloudChangesCount = count
        }
    }

    func markCloudSyncSuccess(forGroupId groupId: String?) {
        let date = Date()
        let defaults = UserDefaults.standard
        defaults.set(date, forKey: syncKey("lastSyncAt", groupId: groupId))
        defaults.removeObject(forKey: syncKey("lastError", groupId: groupId))

        if groupKey(groupId) == groupKey(currentGroupId) {
            lastCloudSyncAt = date
            lastCloudSyncError = nil
        }
    }

    func markCloudSyncFailure(_ error: Error, forGroupId groupId: String?) {
        let message = String(describing: error)
        let defaults = UserDefaults.standard
        defaults.set(message, forKey: syncKey("lastError", groupId: groupId))

        if groupKey(groupId) == groupKey(currentGroupId) {
            lastCloudSyncError = message
        }
    }
}

private extension MovieStore {
    private static let syncMetaPrefix = "MovieStore.SyncMeta."

    func syncKey(_ suffix: String, groupId: String?) -> String {
        Self.syncMetaPrefix + groupKey(groupId) + "." + suffix
    }
}
