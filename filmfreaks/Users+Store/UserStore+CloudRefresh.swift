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
        guard let gid = CloudKitRouting.normalizedGroupId(currentGroupId) else {
            // Standard-/Offline-Gruppe bleibt lokal.
            return
        }

        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshAt = Date()

        if isRefreshingFromCloud { return }
        isRefreshingFromCloud = true
        beginCloudSync()
        defer {
            endCloudSync()
            isRefreshingFromCloud = false
        }

        // Local-first member changes are submitted before the authoritative fetch. The pending
        // journal still protects the change when this attempt cannot reach CloudKit.
        flushPendingMemberCloudChanges()

        do {
            let members = try await cloudStore.fetchMembers(forGroupId: gid)

            // A group switch during the fetch must never overwrite the members of the new group.
            guard CloudKitRouting.normalizedGroupId(currentGroupId) == gid else { return }

            let resolvedMembers = membersApplyingPendingCloudChanges(members, groupId: gid)

            if !resolvedMembers.isEmpty {
                applyCloudUsers(members: resolvedMembers, groupId: gid)
                recordCloudSyncSuccess(forGroupId: gid)
            } else {
                // Cloud leer → falls lokal bereits Users existieren, als „Initial-Seed“ hochladen.
                // Die Outbox hält den Seed auch über einen App-Neustart hinweg fest.
                if !users.isEmpty {
                    for user in users {
                        queueMemberUpsertForCloud(user)
                    }
                    flushPendingMemberCloudChanges()
                    recordCloudSyncSuccess(forGroupId: gid)
                } else {
                    // Cloud fetch succeeded, just no members yet.
                    recordCloudSyncSuccess(forGroupId: gid)
                }
            }
        } catch {
            recordCloudSyncError(error, forGroupId: gid)
            print("UserStore: Fehler beim Laden aus CloudKit: \(error)")
        }
    }
}
