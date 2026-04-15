//
//  MovieNightStore+CloudRefresh.swift
//  filmfreaks
//
//  Split from MovieNightStore+CloudFlush.swift (MOVIENIGHT-STORE-RESPONSIBILITY-SPLIT-1)
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
        if let task = initialLoadTask {
            await task.value
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

    // MARK: - Cloud merge helpers

    func applyCloudChanges(_ delta: CloudKitMovieNightStore.MovieNightChanges, groupId: String) {
        mergeEvents(delta.changedEvents, deleted: delta.deletedEventIDs, groupId: groupId)
        mergeResponses(delta.changedResponses, deleted: delta.deletedResponseIDs, groupId: groupId)
        mergeActivity(delta.changedActivity, deleted: delta.deletedActivityIDs, groupId: groupId)
        mergeRoulettePresets(delta.changedPresets, deleted: delta.deletedPresetIDs, groupId: groupId)
    }

    func applyCloudSnapshot(_ snapshot: CloudKitMovieNightStore.MovieNightSnapshot, groupId: String) {
        // Snapshot path is mainly for legacy/public groups.
        // We merge in a way that never deletes local-only data.
        mergeEvents(snapshot.events, deleted: [], groupId: groupId)
        mergeResponses(snapshot.responses, deleted: [], groupId: groupId)
        mergeActivity(snapshot.activity, deleted: [], groupId: groupId)
        mergeRoulettePresets(snapshot.presets, deleted: [], groupId: groupId)
    }

    func mergeEvents(_ changed: [MovieNightEvent], deleted: [UUID], groupId: String) {
        var current = eventsByGroup[groupId] ?? []
        var byId: [UUID: MovieNightEvent] = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for event in changed {
            if let local = byId[event.id] {
                // Keep the newest version (best-effort, local can still be ahead in Phase 3).
                if local.updatedAt >= event.updatedAt {
                    continue
                }
            }
            byId[event.id] = event
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

        for response in changed {
            if let local = byId[response.id] {
                // respondedAt is our best proxy for "newer".
                if local.respondedAt >= response.respondedAt {
                    continue
                }
            }
            byId[response.id] = response
        }

        for id in deleted {
            byId.removeValue(forKey: id)
        }

        responsesByGroup[groupId] = Array(byId.values)
    }

    func mergeActivity(_ changed: [MovieNightActivityEvent], deleted: [UUID], groupId: String) {
        var current = activityByGroup[groupId] ?? []
        var byId: [UUID: MovieNightActivityEvent] = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })

        for activity in changed {
            byId[activity.id] = activity
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
