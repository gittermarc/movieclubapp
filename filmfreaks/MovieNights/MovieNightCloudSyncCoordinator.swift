//
//  MovieNightCloudSyncCoordinator.swift
//  filmfreaks
//
//  Debounced + batched CloudKit sync for Movie Nights.
//

import Foundation

/// Debounced + batched CloudKit writer for movie night changes.
///
/// Mirrors the approach used for Movies (`MovieCloudSyncCoordinator`) but
/// supports multiple record types (events, responses, activity).
@MainActor
final class MovieNightCloudSyncCoordinator {

    struct PendingEventSave {
        var groupId: String
        var event: MovieNightEvent
        var token: UUID
    }

    struct PendingActivitySave {
        var groupId: String
        var activity: MovieNightActivityEvent
        var token: UUID
    }

    struct PendingResponseSave {
        var groupId: String
        var response: MovieNightResponse
        var token: UUID
    }

    struct PendingPresetSave {
        var groupId: String
        var preset: MovieRoulettePreset
        var token: UUID
    }

    struct PendingDelete {
        var groupId: String
        var token: UUID
    }

    struct PendingResponseDelete {
        var groupId: String
        var eventId: UUID
        var userId: UUID
        var token: UUID
    }

    private static let maxCloudKitModificationsPerOperation = MovieNightCloudKitModificationBatcher.defaultMaxItemsPerBatch

    private let cloudStore: CloudKitMovieNightStore
    private let beginSync: () -> Void
    private let endSync: () -> Void
    private let networkIsAvailable: () -> Bool
    private let pendingCountDidChange: (_ count: Int, _ groupId: String) -> Void
    private let batchDidSucceed: (_ groupId: String) -> Void
    private let batchDidFail: (_ error: Error, _ groupId: String) -> Void

    private let debounceNanoseconds: UInt64

    private var pendingEventSaves: [UUID: PendingEventSave] = [:]
    private var pendingEventDeletes: [UUID: PendingDelete] = [:]

    private var pendingResponseSaves: [String: PendingResponseSave] = [:]
    private var pendingResponseDeletes: [String: PendingResponseDelete] = [:]

    private var pendingActivitySaves: [UUID: PendingActivitySave] = [:]
    private var pendingActivityDeletes: [UUID: PendingDelete] = [:]

    private var pendingPresetSaves: [UUID: PendingPresetSave] = [:]
    private var pendingPresetDeletes: [UUID: PendingDelete] = [:]

    private var scheduledFlush: Task<Void, Never>?
    private var isFlushing: Bool = false

    init(
        cloudStore: CloudKitMovieNightStore,
        debounce: TimeInterval = 0.8,
        beginSync: @escaping () -> Void,
        endSync: @escaping () -> Void,
        networkIsAvailable: @escaping () -> Bool,
        pendingCountDidChange: @escaping (_ count: Int, _ groupId: String) -> Void,
        batchDidSucceed: @escaping (_ groupId: String) -> Void,
        batchDidFail: @escaping (_ error: Error, _ groupId: String) -> Void
    ) {
        self.cloudStore = cloudStore
        self.beginSync = beginSync
        self.endSync = endSync
        self.networkIsAvailable = networkIsAvailable
        self.pendingCountDidChange = pendingCountDidChange
        self.batchDidSucceed = batchDidSucceed
        self.batchDidFail = batchDidFail

        let ns = max(0.05, debounce) * 1_000_000_000
        self.debounceNanoseconds = UInt64(ns)
    }

    // MARK: - Queue API

    func queueEventSave(_ event: MovieNightEvent, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingEventSaves[event.id] = PendingEventSave(groupId: gid, event: event, token: UUID())
        pendingEventDeletes.removeValue(forKey: event.id)
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    func queueEventDelete(eventId: UUID, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingEventSaves.removeValue(forKey: eventId)
        pendingEventDeletes[eventId] = PendingDelete(groupId: gid, token: UUID())
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    func queueResponseSave(_ response: MovieNightResponse, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingResponseSaves[response.id] = PendingResponseSave(groupId: gid, response: response, token: UUID())
        pendingResponseDeletes.removeValue(forKey: response.id)
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    func queueResponseDelete(eventId: UUID, userId: UUID, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        let key = compositeResponseKey(eventId: eventId, userId: userId)
        pendingResponseSaves.removeValue(forKey: key)
        pendingResponseDeletes[key] = PendingResponseDelete(groupId: gid, eventId: eventId, userId: userId, token: UUID())
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    func queueActivitySave(_ activity: MovieNightActivityEvent, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingActivitySaves[activity.id] = PendingActivitySave(groupId: gid, activity: activity, token: UUID())
        pendingActivityDeletes.removeValue(forKey: activity.id)
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    func queueActivityDelete(activityId: UUID, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingActivitySaves.removeValue(forKey: activityId)
        pendingActivityDeletes[activityId] = PendingDelete(groupId: gid, token: UUID())
        publishPendingCount(for: gid)
        scheduleFlush()
    }


    func queuePresetSave(_ preset: MovieRoulettePreset, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingPresetSaves[preset.id] = PendingPresetSave(groupId: gid, preset: preset, token: UUID())
        pendingPresetDeletes.removeValue(forKey: preset.id)
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    func queuePresetDelete(presetId: UUID, groupId: String) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }
        pendingPresetSaves.removeValue(forKey: presetId)
        pendingPresetDeletes[presetId] = PendingDelete(groupId: gid, token: UUID())
        publishPendingCount(for: gid)
        scheduleFlush()
    }

    /// Useful for "I just did a bulk change, please push now" moments.
    func flushImmediately() {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        Task { await self.flushNow() }
    }

    // MARK: - Flush

    /// Heuristik: groupId als UUID => sehr wahrscheinlich eine Sharing/Zone-Gruppe.
    /// Ohne GroupContext dürfen wir **nicht** auf Public DB ausweichen.
    private func requiresGroupContext(_ groupId: String) -> Bool {
        UUID(uuidString: groupId) != nil
    }

    private func isRoutingReady(for groupId: String) -> Bool {
        if GroupContextStore.context(forGroupId: groupId) != nil { return true }
        return !requiresGroupContext(groupId)
    }

    private func scheduleFlush() {
        scheduledFlush?.cancel()
        scheduledFlush = Task { [debounceNanoseconds] in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            await self.flushNow()
        }
    }

    private func flushNow() async {
        if isFlushing { return }
        guard networkIsAvailable() else { return }

        let groupIds = pendingGroupIds()
        guard !groupIds.isEmpty else { return }

        isFlushing = true
        beginSync()
        defer {
            endSync()
            isFlushing = false
        }

        // Flush group-by-group so routing (db/zone) stays simple.
        for gid in groupIds {
            let snapshot = snapshotForGroup(gid)
            if snapshot.isEmpty { continue }

            // WICHTIG: Sharing/Zone Gruppen dürfen niemals in die Public DB fallen.
            // Wenn der GroupContext noch nicht geladen ist, behalten wir die Changes lokal
            // und warten auf den nächsten Trigger (SceneActive / groupStore.refresh / manuell).
            guard isRoutingReady(for: gid) else {
                publishPendingCount(for: gid)
                continue
            }

            do {
                let batches = snapshot.cloudKitModificationBatches(
                    maxItemsPerBatch: Self.maxCloudKitModificationsPerOperation
                )

                for batch in batches {
                    try await cloudStore.modifyBatch(
                        groupId: gid,
                        saveEvents: batch.eventsToSave,
                        deleteEventIDs: batch.eventIDsToDelete,
                        saveResponses: batch.responsesToSave,
                        deleteResponses: batch.responsesToDelete,
                        saveActivity: batch.activityToSave,
                        deleteActivityIDs: batch.activityIDsToDelete,
                        savePresets: batch.presetsToSave,
                        deletePresetIDs: batch.presetIDsToDelete
                    )

                    removePendingEntries(from: batch)
                    publishPendingCount(for: gid)
                }

                batchDidSucceed(gid)

            } catch {
                // Keep failed and superseded pending changes so the UI can show "ausstehend"
                // and the next flush can retry only what is still locally pending.
                publishPendingCount(for: gid)
                batchDidFail(error, gid)
                break
            }
        }

        // If new changes arrived during the flush, schedule another pass quickly.
        // Aber nur, wenn es auch wirklich eine Gruppe gibt, die wir aktuell routen können.
        let remainingEligible = pendingGroupIds().filter { isRoutingReady(for: $0) }
        if !remainingEligible.isEmpty {
            scheduleFlush()
        }
    }

    // MARK: - Pending snapshots

    private enum GroupSnapshotItem {
        case eventSave(UUID, PendingEventSave)
        case eventDelete(UUID, PendingDelete)
        case responseSave(String, PendingResponseSave)
        case responseDelete(String, PendingResponseDelete)
        case activitySave(UUID, PendingActivitySave)
        case activityDelete(UUID, PendingDelete)
        case presetSave(UUID, PendingPresetSave)
        case presetDelete(UUID, PendingDelete)
    }

    private struct GroupSnapshot {
        var eventSaves: [UUID: PendingEventSave]
        var eventDeletes: [UUID: PendingDelete]
        var responseSaves: [String: PendingResponseSave]
        var responseDeletes: [String: PendingResponseDelete]
        var activitySaves: [UUID: PendingActivitySave]
        var activityDeletes: [UUID: PendingDelete]
        var presetSaves: [UUID: PendingPresetSave]
        var presetDeletes: [UUID: PendingDelete]

        init(
            eventSaves: [UUID: PendingEventSave],
            eventDeletes: [UUID: PendingDelete],
            responseSaves: [String: PendingResponseSave],
            responseDeletes: [String: PendingResponseDelete],
            activitySaves: [UUID: PendingActivitySave],
            activityDeletes: [UUID: PendingDelete],
            presetSaves: [UUID: PendingPresetSave],
            presetDeletes: [UUID: PendingDelete]
        ) {
            self.eventSaves = eventSaves
            self.eventDeletes = eventDeletes
            self.responseSaves = responseSaves
            self.responseDeletes = responseDeletes
            self.activitySaves = activitySaves
            self.activityDeletes = activityDeletes
            self.presetSaves = presetSaves
            self.presetDeletes = presetDeletes
        }

        init(items: [GroupSnapshotItem]) {
            self.init(
                eventSaves: [:],
                eventDeletes: [:],
                responseSaves: [:],
                responseDeletes: [:],
                activitySaves: [:],
                activityDeletes: [:],
                presetSaves: [:],
                presetDeletes: [:]
            )

            for item in items {
                switch item {
                case .eventSave(let id, let save):
                    eventSaves[id] = save
                case .eventDelete(let id, let pendingDelete):
                    eventDeletes[id] = pendingDelete
                case .responseSave(let key, let save):
                    responseSaves[key] = save
                case .responseDelete(let key, let pendingDelete):
                    responseDeletes[key] = pendingDelete
                case .activitySave(let id, let save):
                    activitySaves[id] = save
                case .activityDelete(let id, let pendingDelete):
                    activityDeletes[id] = pendingDelete
                case .presetSave(let id, let save):
                    presetSaves[id] = save
                case .presetDelete(let id, let pendingDelete):
                    presetDeletes[id] = pendingDelete
                }
            }
        }

        var isEmpty: Bool {
            eventSaves.isEmpty && eventDeletes.isEmpty && responseSaves.isEmpty && responseDeletes.isEmpty && activitySaves.isEmpty && activityDeletes.isEmpty && presetSaves.isEmpty && presetDeletes.isEmpty
        }

        var eventsToSave: [MovieNightEvent] { eventSaves.values.map { $0.event } }
        var eventIDsToDelete: [UUID] { Array(eventDeletes.keys) }

        var responsesToSave: [MovieNightResponse] { responseSaves.values.map { $0.response } }
        var responsesToDelete: [(eventId: UUID, userId: UUID)] { responseDeletes.values.map { ($0.eventId, $0.userId) } }

        var activityToSave: [MovieNightActivityEvent] { activitySaves.values.map { $0.activity } }
        var activityIDsToDelete: [UUID] { Array(activityDeletes.keys) }

        var presetsToSave: [MovieRoulettePreset] { presetSaves.values.map { $0.preset } }
        var presetIDsToDelete: [UUID] { Array(presetDeletes.keys) }

        func cloudKitModificationBatches(maxItemsPerBatch: Int) -> [GroupSnapshot] {
            MovieNightCloudKitModificationBatcher
                .chunks(items: modificationItems, maxItemsPerBatch: maxItemsPerBatch)
                .map { GroupSnapshot(items: $0) }
        }

        private var modificationItems: [GroupSnapshotItem] {
            var items: [GroupSnapshotItem] = []
            items.reserveCapacity(
                eventSaves.count
                + eventDeletes.count
                + responseSaves.count
                + responseDeletes.count
                + activitySaves.count
                + activityDeletes.count
                + presetSaves.count
                + presetDeletes.count
            )

            for (id, save) in eventSaves.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                items.append(.eventSave(id, save))
            }
            for (id, pendingDelete) in eventDeletes.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                items.append(.eventDelete(id, pendingDelete))
            }
            for (key, save) in responseSaves.sorted(by: { $0.key < $1.key }) {
                items.append(.responseSave(key, save))
            }
            for (key, pendingDelete) in responseDeletes.sorted(by: { $0.key < $1.key }) {
                items.append(.responseDelete(key, pendingDelete))
            }
            for (id, save) in activitySaves.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                items.append(.activitySave(id, save))
            }
            for (id, pendingDelete) in activityDeletes.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                items.append(.activityDelete(id, pendingDelete))
            }
            for (id, save) in presetSaves.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                items.append(.presetSave(id, save))
            }
            for (id, pendingDelete) in presetDeletes.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                items.append(.presetDelete(id, pendingDelete))
            }

            return items
        }
    }

    private func removePendingEntries(from snapshot: GroupSnapshot) {
        // Only remove entries that have not been superseded during the flush.
        for (id, sent) in snapshot.eventSaves {
            if let current = pendingEventSaves[id], current.token == sent.token {
                pendingEventSaves.removeValue(forKey: id)
            }
        }
        for (id, sent) in snapshot.eventDeletes {
            if let current = pendingEventDeletes[id], current.token == sent.token {
                pendingEventDeletes.removeValue(forKey: id)
            }
        }

        for (key, sent) in snapshot.responseSaves {
            if let current = pendingResponseSaves[key], current.token == sent.token {
                pendingResponseSaves.removeValue(forKey: key)
            }
        }
        for (key, sent) in snapshot.responseDeletes {
            if let current = pendingResponseDeletes[key], current.token == sent.token {
                pendingResponseDeletes.removeValue(forKey: key)
            }
        }

        for (id, sent) in snapshot.activitySaves {
            if let current = pendingActivitySaves[id], current.token == sent.token {
                pendingActivitySaves.removeValue(forKey: id)
            }
        }
        for (id, sent) in snapshot.activityDeletes {
            if let current = pendingActivityDeletes[id], current.token == sent.token {
                pendingActivityDeletes.removeValue(forKey: id)
            }
        }

        for (id, sent) in snapshot.presetSaves {
            if let current = pendingPresetSaves[id], current.token == sent.token {
                pendingPresetSaves.removeValue(forKey: id)
            }
        }
        for (id, sent) in snapshot.presetDeletes {
            if let current = pendingPresetDeletes[id], current.token == sent.token {
                pendingPresetDeletes.removeValue(forKey: id)
            }
        }
    }

    private func snapshotForGroup(_ groupId: String) -> GroupSnapshot {
        let eventsToSave = pendingEventSaves.filter { $0.value.groupId == groupId }
        let eventsToDelete = pendingEventDeletes.filter { $0.value.groupId == groupId }
        let responsesToSave = pendingResponseSaves.filter { $0.value.groupId == groupId }
        let responsesToDelete = pendingResponseDeletes.filter { $0.value.groupId == groupId }
        let activityToSave = pendingActivitySaves.filter { $0.value.groupId == groupId }
        let activityToDelete = pendingActivityDeletes.filter { $0.value.groupId == groupId }
        let presetsToSave = pendingPresetSaves.filter { $0.value.groupId == groupId }
        let presetsToDelete = pendingPresetDeletes.filter { $0.value.groupId == groupId }

        return GroupSnapshot(
            eventSaves: eventsToSave,
            eventDeletes: eventsToDelete,
            responseSaves: responsesToSave,
            responseDeletes: responsesToDelete,
            activitySaves: activityToSave,
            activityDeletes: activityToDelete,
            presetSaves: presetsToSave,
            presetDeletes: presetsToDelete
        )
    }

    private func pendingGroupIds() -> [String] {
        var ids: Set<String> = []
        ids.formUnion(pendingEventSaves.values.map { $0.groupId })
        ids.formUnion(pendingEventDeletes.values.map { $0.groupId })
        ids.formUnion(pendingResponseSaves.values.map { $0.groupId })
        ids.formUnion(pendingResponseDeletes.values.map { $0.groupId })
        ids.formUnion(pendingActivitySaves.values.map { $0.groupId })
        ids.formUnion(pendingActivityDeletes.values.map { $0.groupId })
        ids.formUnion(pendingPresetSaves.values.map { $0.groupId })
        ids.formUnion(pendingPresetDeletes.values.map { $0.groupId })
        return ids.sorted()
    }

    private func publishPendingCount(for groupId: String) {
        let count = pendingEventSaves.values.filter { $0.groupId == groupId }.count
            + pendingEventDeletes.values.filter { $0.groupId == groupId }.count
            + pendingResponseSaves.values.filter { $0.groupId == groupId }.count
            + pendingResponseDeletes.values.filter { $0.groupId == groupId }.count
            + pendingActivitySaves.values.filter { $0.groupId == groupId }.count
            + pendingActivityDeletes.values.filter { $0.groupId == groupId }.count
            + pendingPresetSaves.values.filter { $0.groupId == groupId }.count
            + pendingPresetDeletes.values.filter { $0.groupId == groupId }.count
        pendingCountDidChange(count, groupId)
    }

    private func compositeResponseKey(eventId: UUID, userId: UUID) -> String {
        "\(eventId.uuidString)_\(userId.uuidString)"
    }
}
