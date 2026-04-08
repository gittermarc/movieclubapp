//
//  UserStore+CloudRefresh.swift
//  filmfreaks
//
//  Split from UserStore.swift
//

import Foundation

extension UserStore {

    // MARK: - Cloud refresh

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
        lastCloudSyncAttemptAt = Date()
        isSyncing = true
        defer { isSyncing = false }

        do {
            let members = try await cloudStore.fetchMembers(forGroupId: gid)

            if !members.isEmpty {
                applyCloudUsers(members: members, groupId: gid)
                recordCloudSyncSuccess()
            } else {
                // Cloud leer → falls lokal bereits Users existieren, als „Initial-Seed“ hochladen.
                // (So hat der Gruppenersteller sofort Members in der Cloud.)
                if !users.isEmpty {
                    for user in users {
                        do {
                            try await cloudStore.upsertMember(id: user.id, name: user.name, groupId: gid)
                        } catch {
                            print("CloudKitUserStore upsert bootstrap error: \(error)")
                        }
                    }

                    let seededMembers = try await cloudStore.fetchMembers(forGroupId: gid)
                    if !seededMembers.isEmpty {
                        applyCloudUsers(members: seededMembers, groupId: gid)
                        recordCloudSyncSuccess()
                    }
                } else {
                    // Cloud fetch succeeded, just no members yet.
                    recordCloudSyncSuccess()
                }
            }
        } catch {
            recordCloudSyncError(error)
            print("UserStore: Fehler beim Laden aus CloudKit: \(error)")
        }
    }
}
