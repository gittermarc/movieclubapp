//
//  MovieNightStore+SyncMeta.swift
//  filmfreaks
//
//  Split from MovieNightStore+CloudFlush.swift (MOVIENIGHT-STORE-RESPONSIBILITY-SPLIT-1)
//

import Foundation

extension MovieNightStore {

    // MARK: - Sync meta

    func beginSync() {
        syncCount += 1
        if syncCount == 1 {
            isSyncing = true
        }
    }

    func endSync() {
        syncCount = max(0, syncCount - 1)
        if syncCount == 0 {
            isSyncing = false
        }
    }

    func applyPendingCount(_ count: Int, forGroupId groupId: String) {
        pendingCloudChangesByGroup[groupId] = count
        UserDefaults.standard.set(count, forKey: syncMetaKey(groupId, "pending"))
    }

    func markCloudSyncSuccess(forGroupId groupId: String) {
        lastCloudSyncAtByGroup[groupId] = .now
        lastCloudSyncErrorByGroup.removeValue(forKey: groupId)

        UserDefaults.standard.set(Date(), forKey: syncMetaKey(groupId, "lastAt"))
        UserDefaults.standard.removeObject(forKey: syncMetaKey(groupId, "lastError"))
    }

    func markCloudSyncFailure(_ error: Error, forGroupId groupId: String) {
        let msg = String(describing: error)
        lastCloudSyncErrorByGroup[groupId] = msg
        UserDefaults.standard.set(msg, forKey: syncMetaKey(groupId, "lastError"))
    }

    func ensureSyncMetaLoaded(forGroupId groupId: String) {
        // Only load once per group. Pending count can legitimately be 0.
        if pendingCloudChangesByGroup.keys.contains(groupId) {
            return
        }

        let pending = UserDefaults.standard.integer(forKey: syncMetaKey(groupId, "pending"))
        pendingCloudChangesByGroup[groupId] = pending

        if let lastAt = UserDefaults.standard.object(forKey: syncMetaKey(groupId, "lastAt")) as? Date {
            lastCloudSyncAtByGroup[groupId] = lastAt
        }

        if let err = UserDefaults.standard.string(forKey: syncMetaKey(groupId, "lastError")), !err.isEmpty {
            lastCloudSyncErrorByGroup[groupId] = err
        }
    }

    func syncMetaKey(_ groupId: String, _ suffix: String) -> String {
        GroupScopedStorage.UserDefaultsKey.movieNightSyncMeta(groupId: groupId, suffix: suffix)
    }
}
