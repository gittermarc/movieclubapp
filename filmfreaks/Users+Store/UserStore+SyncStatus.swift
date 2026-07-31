//
//  UserStore+SyncStatus.swift
//  filmfreaks
//
//  Split from UserStore.swift
//

import Foundation

extension UserStore {

    // MARK: - Per-group sync status persistence

    func syncKey(for groupId: String?) -> String {
        GroupScopedStorage.selectedUserGroupKey(for: groupId)
    }

    func applySyncStatusForCurrentGroup() {
        let key = syncKey(for: currentGroupId)
        let status = syncStatusByGroup[key] ?? SyncStatus()
        lastCloudSyncSuccessAt = status.lastSuccessAt
        lastCloudSyncAttemptAt = status.lastAttemptAt
        lastCloudSyncErrorMessage = status.lastErrorMessage
        lastCloudSyncErrorAt = status.lastErrorAt
    }

    func persistSyncStatusByGroup() {
        guard let data = try? JSONEncoder().encode(syncStatusByGroup) else { return }
        UserDefaults.standard.set(data, forKey: Self.syncStatusByGroupKey)
    }

    static func loadSyncStatusByGroup() -> [String: SyncStatus] {
        guard let data = UserDefaults.standard.data(forKey: syncStatusByGroupKey),
              let decoded = try? JSONDecoder().decode([String: SyncStatus].self, from: data) else {
            return [:]
        }
        return decoded
    }

    // MARK: - Sync status recording

    func recordCloudSyncSuccess(forGroupId groupId: String? = nil) {
        let now = Date()

        let resolvedGroupId = groupId ?? currentGroupId
        let key = syncKey(for: resolvedGroupId)
        var status = syncStatusByGroup[key] ?? SyncStatus()
        status.lastSuccessAt = now
        status.lastAttemptAt = now
        status.lastErrorMessage = nil
        status.lastErrorAt = nil
        syncStatusByGroup[key] = status
        persistSyncStatusByGroup()

        guard key == syncKey(for: currentGroupId) else { return }
        lastCloudSyncSuccessAt = now
        lastCloudSyncAttemptAt = now
        lastCloudSyncErrorMessage = nil
        lastCloudSyncErrorAt = nil
    }

    func recordCloudSyncError(_ error: Error, forGroupId groupId: String? = nil) {
        let now = Date()
        let msg = UserStoreCloudErrorFormatter.message(for: error)

        let resolvedGroupId = groupId ?? currentGroupId
        let key = syncKey(for: resolvedGroupId)
        var status = syncStatusByGroup[key] ?? SyncStatus()
        status.lastAttemptAt = now
        status.lastErrorAt = now
        status.lastErrorMessage = msg
        syncStatusByGroup[key] = status
        persistSyncStatusByGroup()

        guard key == syncKey(for: currentGroupId) else { return }
        lastCloudSyncAttemptAt = now
        lastCloudSyncErrorAt = now
        lastCloudSyncErrorMessage = msg
    }
}
