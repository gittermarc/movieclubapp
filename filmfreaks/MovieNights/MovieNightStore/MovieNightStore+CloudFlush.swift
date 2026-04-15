//
//  MovieNightStore+CloudFlush.swift
//  filmfreaks
//
//  Split from MovieNightStore.swift (P0.3)
//

import Foundation

extension MovieNightStore {

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

        for response in responsesToSave {
            coordinator.queueResponseSave(response, groupId: gid)
        }

        for (eventId, userId) in responseDeletes {
            coordinator.queueResponseDelete(eventId: eventId, userId: userId, groupId: gid)
        }

        for activity in activityToSave {
            coordinator.queueActivitySave(activity, groupId: gid)
        }

        for id in activityIDsToDelete {
            coordinator.queueActivityDelete(activityId: id, groupId: gid)
        }
    }
    func queueRoulettePresetSave(_ preset: MovieRoulettePreset, groupId: String) {
        guard useCloud, cloudStore != nil, let coordinator = cloudSyncCoordinator else { return }

        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }

        ensureSyncMetaLoaded(forGroupId: gid)
        coordinator.queuePresetSave(preset, groupId: gid)
    }

    func queueRoulettePresetDelete(presetId: UUID, groupId: String) {
        guard useCloud, cloudStore != nil, let coordinator = cloudSyncCoordinator else { return }

        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }

        ensureSyncMetaLoaded(forGroupId: gid)
        coordinator.queuePresetDelete(presetId: presetId, groupId: gid)
    }

}
