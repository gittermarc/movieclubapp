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

    // MARK: - Published state

    @Published var eventsByGroup: [String: [MovieNightEvent]] = [:]
    @Published var responsesByGroup: [String: [MovieNightResponse]] = [:]
    @Published var activityByGroup: [String: [MovieNightActivityEvent]] = [:]
    @Published var isLoaded: Bool = false

    // MARK: - Sync transparency (per group)

    /// Combined sync state (fetch + upload). We use a counter to avoid flicker.
    @Published var isSyncing: Bool = false

    /// Number of locally queued changes that still need to be pushed to iCloud (per group).
    @Published var pendingCloudChangesByGroup: [String: Int] = [:]

    /// Timestamp of the last successful sync (fetch or upload) per group.
    @Published var lastCloudSyncAtByGroup: [String: Date] = [:]

    /// Last sync error message (best effort) per group. Cleared on success.
    @Published var lastCloudSyncErrorByGroup: [String: String] = [:]

    // MARK: - Cloud

    let useCloud: Bool
    let cloudStore: CloudKitMovieNightStore?

    var isRefreshingFromCloud: Bool = false
    var lastRefreshAtByGroup: [String: Date] = [:]
    let minRefreshInterval: TimeInterval = 8

    var cloudSyncCoordinator: MovieNightCloudSyncCoordinator?

    // Combined sync state (fetch + upload). We use a counter to avoid flicker.
    var syncCount: Int = 0

    // MARK: - Network reconnect handling

    var networkCancellable: AnyCancellable?
    var lastNetworkConnected: Bool = true

    // MARK: - GroupContext retry handling

    /// When a Sharing/Zone group becomes routable (GroupContext persisted), automatically:
    /// - flush pending writes
    /// - refresh from cloud
    var groupContextCancellable: AnyCancellable?
    var lastGroupContextRetryAtByGroup: [String: Date] = [:]
    let minGroupContextRetryInterval: TimeInterval = 2

    // UserDefaults base key (per group)
    static let syncMetaPrefix = "MovieNightStore.SyncMeta."

    var initialLoadTask: Task<Void, Never>?

    let persistence = MovieNightLocalPersistence()

    init(useCloud: Bool = true, cloudStore: CloudKitMovieNightStore? = nil) {
        self.useCloud = useCloud

        if useCloud {
            // Avoid constructing a MainActor-isolated CloudKit store as a default argument.
            // Default arguments are evaluated in the caller's context, which can be nonisolated.
            let resolved = cloudStore ?? CloudKitMovieNightStore()
            self.cloudStore = resolved
        } else {
            self.cloudStore = nil
        }

        self.initialLoadTask = Task { @MainActor in
            let snapshot = await persistence.load()
            self.eventsByGroup = snapshot.eventsByGroup
            self.responsesByGroup = snapshot.responsesByGroup
            self.activityByGroup = snapshot.activityByGroup
            self.isLoaded = true
        }

        if useCloud, let cloudStore = self.cloudStore {
            self.cloudSyncCoordinator = MovieNightCloudSyncCoordinator(
                cloudStore: cloudStore,
                beginSync: { [weak self] in self?.beginSync() },
                endSync: { [weak self] in self?.endSync() },
                networkIsAvailable: { NetworkMonitor.shared.isConnected },
                pendingCountDidChange: { [weak self] count, groupId in
                    self?.applyPendingCount(count, forGroupId: groupId)
                },
                batchDidSucceed: { [weak self] groupId in
                    self?.markCloudSyncSuccess(forGroupId: groupId)
                },
                batchDidFail: { [weak self] error, groupId in
                    self?.markCloudSyncFailure(error, forGroupId: groupId)
                }
            )
        }

        setupNetworkReconnectHandling()
        setupGroupContextRetryHandling()
    }

    private func setupGroupContextRetryHandling() {
        groupContextCancellable = NotificationCenter.default.publisher(for: .groupContextDidUpsert)
            .compactMap { $0.userInfo?["groupId"] as? String }
            .sink { [weak self] groupId in
                guard let self else { return }
                Task { @MainActor in
                    self.handleGroupContextUpsert(groupId: groupId)
                }
            }
    }

    private func handleGroupContextUpsert(groupId: String) {
        guard let normalized = CloudKitRouting.normalizedGroupId(groupId) else { return }

        // Only relevant for UUID-like groupIds.
        guard CloudKitRouting.requiresGroupContext(for: normalized) else { return }
        guard GroupContextStore.context(forGroupId: normalized) != nil else { return }

        // Throttle duplicate upserts (group list refresh may upsert multiple times).
        let now = Date()
        if let last = lastGroupContextRetryAtByGroup[normalized], now.timeIntervalSince(last) < minGroupContextRetryInterval {
            return
        }
        lastGroupContextRetryAtByGroup[normalized] = now

        flushPendingCloudChanges()
        Task { await self.refreshFromCloud(groupId: normalized, force: true) }
    }

    // MARK: - Write API

    @discardableResult
    func proposeEvent(
        groupId: String,
        proposedStart: Date,
        suggestedMovie: MovieNightMovieRef? = nil,
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
            suggestedMovie: suggestedMovie,
            note: note,
            status: .open
        )

        var list = eventsByGroup[groupId] ?? []
        list.append(event)
        list.sort(by: { $0.proposedStart < $1.proposedStart })
        eventsByGroup[groupId] = list

        let activity = MovieNightActivityEvent(
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
        )
        appendActivity(activity, groupId: groupId)

        queueCloudWrites(
            groupId: groupId,
            eventToSave: event,
            responsesToSave: [],
            activityToSave: [activity],
            eventIDsToDelete: [],
            responseDeletes: [],
            activityIDsToDelete: []
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

        var activityToSave: [MovieNightActivityEvent] = []

        if let newStatus = status, newStatus != beforeStatus {
            let activity = MovieNightActivityEvent(
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
            )
            appendActivity(activity, groupId: groupId)
            activityToSave.append(activity)
        }

        queueCloudWrites(
            groupId: groupId,
            eventToSave: event,
            responsesToSave: [],
            activityToSave: activityToSave,
            eventIDsToDelete: [],
            responseDeletes: [],
            activityIDsToDelete: []
        )

        persist()
    }

    func deleteEvent(
        groupId: String,
        eventId: UUID,
        actorUserId: UUID? = nil,
        actorName: String? = nil
    ) {
        let removedResponses = (responsesByGroup[groupId] ?? []).filter { $0.eventId == eventId }

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

        var activityToSave: [MovieNightActivityEvent] = []

        if let removed {
            let activity = MovieNightActivityEvent(
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
            )
            appendActivity(activity, groupId: groupId)
            activityToSave.append(activity)
        }

        queueCloudWrites(
            groupId: groupId,
            eventToSave: nil,
            responsesToSave: [],
            activityToSave: activityToSave,
            eventIDsToDelete: [eventId],
            responseDeletes: removedResponses.map { ($0.eventId, $0.userId) },
            activityIDsToDelete: []
        )

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

        let updatedResponse: MovieNightResponse

        if let idx = responses.firstIndex(where: { $0.eventId == eventId && $0.userId == userId }) {
            var existing = responses[idx]
            existing.decision = decision
            existing.respondedAt = .now
            existing.userName = userName
            responses[idx] = existing
            updatedResponse = existing
        } else {
            let created = MovieNightResponse(
                eventId: eventId,
                userId: userId,
                userName: userName,
                decision: decision,
                respondedAt: .now
            )
            responses.append(created)
            updatedResponse = created
        }

        responsesByGroup[groupId] = responses

        var activityToSave: [MovieNightActivityEvent] = []

        if let event = events(for: groupId).first(where: { $0.id == eventId }) {
            let activity = MovieNightActivityEvent(
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
            )
            appendActivity(activity, groupId: groupId)
            activityToSave.append(activity)
        }

        queueCloudWrites(
            groupId: groupId,
            eventToSave: nil,
            responsesToSave: [updatedResponse],
            activityToSave: activityToSave,
            eventIDsToDelete: [],
            responseDeletes: [],
            activityIDsToDelete: []
        )

        persist()
    }

    // MARK: - Network reconnect handling

    private func setupNetworkReconnectHandling() {
        // Seed with current state so we only react to transitions.
        lastNetworkConnected = NetworkMonitor.shared.isConnected

        networkCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }

                Task { @MainActor in
                    let wasConnected = self.lastNetworkConnected
                    self.lastNetworkConnected = connected

                    // Only flush on offline -> online.
                    guard connected, !wasConnected else { return }
                    self.flushPendingCloudChanges()
                }
            }
    }
}
