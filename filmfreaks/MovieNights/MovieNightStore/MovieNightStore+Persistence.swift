//
//  MovieNightStore+Persistence.swift
//  filmfreaks
//
//  Split from MovieNightStore.swift (P0.3)
//

import Foundation

extension MovieNightStore {

    // MARK: - Debug / Utilities

    func purgeAllLocalData() {
        eventsByGroup.removeAll()
        responsesByGroup.removeAll()
        activityByGroup.removeAll()
        presetsByGroup.removeAll()

        Task { await persistence.deleteLocalFile() }

        // Persist the empty snapshot so the app state matches disk state even if file delete fails.
        persist()
    }

    // MARK: - Persistence

    func persist() {
        let snapshot = MovieNightLocalPersistence.Snapshot(
            schemaVersion: 3,
            savedAt: .now,
            eventsByGroup: eventsByGroup,
            responsesByGroup: responsesByGroup,
            activityByGroup: activityByGroup,
            presetsByGroup: presetsByGroup
        )

        Task {
            await persistence.save(snapshot)
        }
    }

    func appendActivity(_ event: MovieNightActivityEvent, groupId: String) {
        var list = activityByGroup[groupId] ?? []
        list.append(event)
        // Keep a cap so the JSON doesn't grow forever in P2.
        if list.count > 200 {
            list = Array(list.suffix(200))
        }
        activityByGroup[groupId] = list
    }
}
