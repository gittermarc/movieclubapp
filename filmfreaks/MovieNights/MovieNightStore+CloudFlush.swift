//
//  MovieNightStore+CloudFlush.swift
//  filmfreaks
//
//  Split from MovieNightStore.swift (P0.3)
//

import Foundation

extension MovieNightStore {

    // MARK: - Cloud read (Phase 3)

    /// Pulls movie night data from CloudKit for a given group and merges it into the local snapshot.
    ///
    /// Phase 3 is read-only: local changes are NOT uploaded yet.
    func refreshFromCloud(groupId: String?, force: Bool = false) async {
        guard useCloud, let cloudStore else { return }

        let gid = (groupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else {
            // No group -> local-only.
            return
        }

        ensureSyncMetaLoaded(forGroupId: gid)

        // Sharing/Zone Gruppen (UUID groupId) dürfen niemals in die Public DB fallen.
        // Wenn der GroupContext noch nicht geladen ist, brechen wir ab und versuchen es
        // später erneut (z.B. nach groupStore.refresh / SceneActive).
        if UUID(uuidString: gid) != nil, GroupContextStore.context(forGroupId: gid) == nil {
            return
        }

        // Ensure local snapshot has been loaded, otherwise we'd overwrite cloud merges.
        if let t = initialLoadTask {
            await t.value
        }

        if isRefreshingFromCloud { return }
        if !force, let last = lastRefreshAtByGroup[gid], Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }

        lastRefreshAtByGroup[gid] = Date()
        isRefreshingFromCloud = true
        beginSync()
        defer {
            isRefreshingFromCloud = false
            endSync()
        }

        do {
            if GroupContextStore.context(forGroupId: gid) != nil {
                let changes = try await cloudStore.fetchMovieNightChanges(forGroupId: gid)
                applyCloudChanges(changes, groupId: gid)
            } else {
                let snapshot = try await cloudStore.fetchMovieNightSnapshot(forGroupId: gid)
                applyCloudSnapshot(snapshot, groupId: gid)
            }

            persist()
            markCloudSyncSuccess(forGroupId: gid)
        } catch {
            print("MovieNightStore.refreshFromCloud error: \(error)")
            markCloudSyncFailure(error, forGroupId: gid)
        }
    }

    // MARK: - Cloud write (Phase 4)

    func flushPendingCloudChanges() {
        cloudSyncCoordinator?.flushImmediately()
    }

    func queueCloudWrites(
        groupId: String,
        eventToSave: MovieNightEvent?,
        responsesToSave: [MovieNightResponse],
        activityToSave: [MovieNightActivityEvent],
        eventIDsToDelete: [UUID],
        responseDeletes: [(UUID, UUID)],
        activityIDsToDelete: [UUID]
    ) {
        guard useCloud, cloudStore != nil, let coordinator = cloudSyncCoordinator else { return }

        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }

        ensureSyncMetaLoaded(forGroupId: gid)

        if let eventToSave {
            coordinator.queueEventSave(eventToSave, groupId: gid)
        }

        for id in eventIDsToDelete {
            coordinator.queueEventDelete(eventId: id, groupId: gid)
        }

        for r in responsesToSave {
            coordinator.queueResponseSave(r, groupId: gid)
        }

        for (eventId, userId) in responseDeletes {
            coordinator.queueResponseDelete(eventId: eventId, userId: userId, groupId: gid)
        }

        for a in activityToSave {
            coordinator.queueActivitySave(a, groupId: gid)
        }

        for id in activityIDsToDelete {
            coordinator.queueActivityDelete(activityId: id, groupId: gid)
        }
    }

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
        Self.syncMetaPrefix + groupId + "." + suffix
    }

    // MARK: - Cloud merge helpers

    func applyCloudChanges(_ delta: CloudKitMovieNightStore.MovieNightChanges, groupId: String) {
        mergeEvents(delta.changedEvents, deleted: delta.deletedEventIDs, groupId: groupId)
        mergeResponses(delta.changedResponses, deleted: delta.deletedResponseIDs, groupId: groupId)
        mergeActivity(delta.changedActivity, deleted: delta.deletedActivityIDs, groupId: groupId)
    }

    func applyCloudSnapshot(_ snapshot: CloudKitMovieNightStore.MovieNightSnapshot, groupId: String) {
        // Snapshot path is mainly for legacy/public groups.
        // We merge in a way that never deletes local-only data.
        mergeEvents(snapshot.events, deleted: [], groupId: groupId)
        mergeResponses(snapshot.responses, deleted: [], groupId: groupId)
        mergeActivity(snapshot.activity, deleted: [], groupId: groupId)
    }

    func mergeEvents(_ changed: [MovieNightEvent], deleted: [UUID], groupId: String) {
        var current = eventsByGroup[groupId] ?? []
        var byId: [UUID: MovieNightEvent] = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for e in changed {
            if let local = byId[e.id] {
                // Keep the newest version (best-effort, local can still be ahead in Phase 3).
                if local.updatedAt >= e.updatedAt {
                    continue
                }
            }
            byId[e.id] = e
        }

        for id in deleted {
            byId.removeValue(forKey: id)
        }

        current = Array(byId.values)
        current.sort(by: { $0.proposedStart < $1.proposedStart })
        eventsByGroup[groupId] = current
    }

    func mergeResponses(_ changed: [MovieNightResponse], deleted: [String], groupId: String) {
        let current = responsesByGroup[groupId] ?? []
        var byId: [String: MovieNightResponse] = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for r in changed {
            if let local = byId[r.id] {
                // respondedAt is our best proxy for "newer".
                if local.respondedAt >= r.respondedAt {
                    continue
                }
            }
            byId[r.id] = r
        }

        for id in deleted {
            byId.removeValue(forKey: id)
        }

        responsesByGroup[groupId] = Array(byId.values)
    }

    func mergeActivity(_ changed: [MovieNightActivityEvent], deleted: [UUID], groupId: String) {
        var current = activityByGroup[groupId] ?? []
        var byId: [UUID: MovieNightActivityEvent] = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for a in changed {
            byId[a.id] = a
        }

        for id in deleted {
            byId.removeValue(forKey: id)
        }

        current = Array(byId.values)
        current.sort(by: { $0.createdAt > $1.createdAt })
        if current.count > 200 {
            current = Array(current.prefix(200))
        }
        activityByGroup[groupId] = current
    }
}
