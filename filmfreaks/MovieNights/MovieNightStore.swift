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

    private let persistence = MovieNightLocalPersistence()

    init() {
        Task { @MainActor in
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
}
