//
//  MovieNightStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation
internal import SwiftUI
import Combine

/// Group-scoped store for movie night proposals and responses.
///
/// P0: Local-only persistence (JSON) via `MovieNightLocalPersistence`.
/// P2: Adds local activity events + accept/decline flow.
@MainActor
final class MovieNightStore: ObservableObject {

    @Published private(set) var eventsByGroup: [String: [MovieNightEvent]] = [:]
    @Published private(set) var responsesByGroup: [String: [MovieNightResponse]] = [:]
    @Published private(set) var activityByGroup: [String: [MovieNightActivityEvent]] = [:]
    @Published private(set) var isLoaded: Bool = false

    // MARK: - Cloud (Phase 3: read-only)

    private let useCloud: Bool
    private let cloudStore: CloudKitMovieNightStore?

    private var isRefreshingFromCloud: Bool = false
    private var lastRefreshAtByGroup: [String: Date] = [:]
    private let minRefreshInterval: TimeInterval = 8

    private var initialLoadTask: Task<Void, Never>?

    private let persistence = MovieNightLocalPersistence()

    init(useCloud: Bool = true, cloudStore: CloudKitMovieNightStore = CloudKitMovieNightStore()) {
        self.useCloud = useCloud
        self.cloudStore = useCloud ? cloudStore : nil

        self.initialLoadTask = Task { @MainActor in
            let snapshot = await persistence.load()
            self.eventsByGroup = snapshot.eventsByGroup
            self.responsesByGroup = snapshot.responsesByGroup
            self.activityByGroup = snapshot.activityByGroup
            self.isLoaded = true
        }
    }

    // MARK: - Read API

    func events(for groupId: String) -> [MovieNightEvent] {
        (eventsByGroup[groupId] ?? []).sorted(by: { $0.proposedStart < $1.proposedStart })
    }

    func upcomingEvents(for groupId: String, now: Date = .now) -> [MovieNightEvent] {
        events(for: groupId).filter { $0.proposedStart >= now && $0.status != .cancelled }
    }

    func pastEvents(for groupId: String, now: Date = .now) -> [MovieNightEvent] {
        events(for: groupId).filter { $0.proposedStart < now && $0.status != .cancelled }
    }

    func responses(for groupId: String, eventId: UUID) -> [MovieNightResponse] {
        (responsesByGroup[groupId] ?? []).filter { $0.eventId == eventId }
    }

    func response(for groupId: String, eventId: UUID, userId: UUID) -> MovieNightResponse? {
        (responsesByGroup[groupId] ?? []).first { $0.eventId == eventId && $0.userId == userId }
    }

    func activityEvents(for groupId: String) -> [MovieNightActivityEvent] {
        (activityByGroup[groupId] ?? []).sorted(by: { $0.createdAt > $1.createdAt })
    }

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
        defer { isRefreshingFromCloud = false }

        do {
            if GroupContextStore.context(forGroupId: gid) != nil {
                let changes = try await cloudStore.fetchMovieNightChanges(forGroupId: gid)
                applyCloudChanges(changes, groupId: gid)
            } else {
                let snapshot = try await cloudStore.fetchMovieNightSnapshot(forGroupId: gid)
                applyCloudSnapshot(snapshot, groupId: gid)
            }

            persist()
        } catch {
            print("MovieNightStore.refreshFromCloud error: \(error)")
        }
    }

    // MARK: - Write API

    @discardableResult
    func proposeEvent(
        groupId: String,
        proposedStart: Date,
        note: String? = nil,
        proposerUserId: UUID,
        proposerName: String
    ) -> MovieNightEvent {
        let now = Date()
        let event = MovieNightEvent(
            groupId: groupId,
            proposedStart: proposedStart,
            createdAt: now,
            updatedAt: now,
            proposerUserId: proposerUserId,
            proposerName: proposerName,
            note: note,
            status: .open
        )

        var list = eventsByGroup[groupId] ?? []
        list.append(event)
        list.sort(by: { $0.proposedStart < $1.proposedStart })
        eventsByGroup[groupId] = list

        appendActivity(
            MovieNightActivityEvent(
                groupId: groupId,
                kind: .proposed,
                createdAt: now,
                eventId: event.id,
                eventStart: event.proposedStart,
                actorUserId: proposerUserId,
                actorName: proposerName,
                decision: nil,
                newStatus: .open,
                note: note
            ),
            groupId: groupId
        )

        persist()
        return event
    }

    func updateEvent(
        groupId: String,
        eventId: UUID,
        proposedStart: Date? = nil,
        note: String?? = nil,
        status: MovieNightEvent.Status? = nil,
        actorUserId: UUID? = nil,
        actorName: String? = nil
    ) {
        guard var list = eventsByGroup[groupId], let idx = list.firstIndex(where: { $0.id == eventId }) else { return }

        var event = list[idx]
        let beforeStatus = event.status

        if let proposedStart { event.proposedStart = proposedStart }
        if let status { event.status = status }
        if let note { event.note = note }
        event.updatedAt = .now

        list[idx] = event
        list.sort(by: { $0.proposedStart < $1.proposedStart })
        eventsByGroup[groupId] = list

        if let newStatus = status, newStatus != beforeStatus {
            appendActivity(
                MovieNightActivityEvent(
                    groupId: groupId,
                    kind: .statusChanged,
                    createdAt: .now,
                    eventId: event.id,
                    eventStart: event.proposedStart,
                    actorUserId: actorUserId ?? event.proposerUserId,
                    actorName: actorName ?? (actorUserId == nil ? "System" : (actorName ?? event.proposerName)),
                    decision: nil,
                    newStatus: newStatus,
                    note: nil
                ),
                groupId: groupId
            )
        }

        persist()
    }

    func deleteEvent(
        groupId: String,
        eventId: UUID,
        actorUserId: UUID? = nil,
        actorName: String? = nil
    ) {
        let removed: MovieNightEvent? = {
            guard let list = eventsByGroup[groupId] else { return nil }
            return list.first(where: { $0.id == eventId })
        }()

        if var list = eventsByGroup[groupId] {
            list.removeAll(where: { $0.id == eventId })
            eventsByGroup[groupId] = list
        }

        if var responses = responsesByGroup[groupId] {
            responses.removeAll(where: { $0.eventId == eventId })
            responsesByGroup[groupId] = responses
        }

        if let removed {
            appendActivity(
                MovieNightActivityEvent(
                    groupId: groupId,
                    kind: .deleted,
                    createdAt: .now,
                    eventId: removed.id,
                    eventStart: removed.proposedStart,
                    actorUserId: actorUserId ?? removed.proposerUserId,
                    actorName: actorName ?? (actorUserId == nil ? "System" : (actorName ?? removed.proposerName)),
                    decision: nil,
                    newStatus: nil,
                    note: removed.note
                ),
                groupId: groupId
            )
        }

        persist()
    }

    func setResponse(
        groupId: String,
        eventId: UUID,
        userId: UUID,
        userName: String,
        decision: MovieNightResponse.Decision
    ) {
        var responses = responsesByGroup[groupId] ?? []

        if let idx = responses.firstIndex(where: { $0.eventId == eventId && $0.userId == userId }) {
            var existing = responses[idx]
            existing.decision = decision
            existing.respondedAt = .now
            existing.userName = userName
            responses[idx] = existing
        } else {
            responses.append(
                MovieNightResponse(
                    eventId: eventId,
                    userId: userId,
                    userName: userName,
                    decision: decision,
                    respondedAt: .now
                )
            )
        }

        responsesByGroup[groupId] = responses

        if let event = events(for: groupId).first(where: { $0.id == eventId }) {
            appendActivity(
                MovieNightActivityEvent(
                    groupId: groupId,
                    kind: .responded,
                    createdAt: .now,
                    eventId: eventId,
                    eventStart: event.proposedStart,
                    actorUserId: userId,
                    actorName: userName,
                    decision: decision,
                    newStatus: nil,
                    note: nil
                ),
                groupId: groupId
            )
        }

        persist()
    }

    // MARK: - Debug / Utilities

    func purgeAllLocalData() {
        eventsByGroup.removeAll()
        responsesByGroup.removeAll()
        activityByGroup.removeAll()

        Task { await persistence.deleteLocalFile() }

        // Persist the empty snapshot so the app state matches disk state even if file delete fails.
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let snapshot = MovieNightLocalPersistence.Snapshot(
            schemaVersion: 2,
            savedAt: .now,
            eventsByGroup: eventsByGroup,
            responsesByGroup: responsesByGroup,
            activityByGroup: activityByGroup
        )

        Task {
            await persistence.save(snapshot)
        }
    }

    private func appendActivity(_ event: MovieNightActivityEvent, groupId: String) {
        var list = activityByGroup[groupId] ?? []
        list.append(event)
        // Keep a cap so the JSON doesn't grow forever in P2.
        if list.count > 200 {
            list = Array(list.suffix(200))
        }
        activityByGroup[groupId] = list
    }

    // MARK: - Cloud merge helpers

    private func applyCloudChanges(_ delta: CloudKitMovieNightStore.MovieNightChanges, groupId: String) {
        mergeEvents(delta.changedEvents, deleted: delta.deletedEventIDs, groupId: groupId)
        mergeResponses(delta.changedResponses, deleted: delta.deletedResponseIDs, groupId: groupId)
        mergeActivity(delta.changedActivity, deleted: delta.deletedActivityIDs, groupId: groupId)
    }

    private func applyCloudSnapshot(_ snapshot: CloudKitMovieNightStore.MovieNightSnapshot, groupId: String) {
        // Snapshot path is mainly for legacy/public groups.
        // We merge in a way that never deletes local-only data.
        mergeEvents(snapshot.events, deleted: [], groupId: groupId)
        mergeResponses(snapshot.responses, deleted: [], groupId: groupId)
        mergeActivity(snapshot.activity, deleted: [], groupId: groupId)
    }

    private func mergeEvents(_ changed: [MovieNightEvent], deleted: [UUID], groupId: String) {
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

    private func mergeResponses(_ changed: [MovieNightResponse], deleted: [String], groupId: String) {
        var current = responsesByGroup[groupId] ?? []
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

    private func mergeActivity(_ changed: [MovieNightActivityEvent], deleted: [UUID], groupId: String) {
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
