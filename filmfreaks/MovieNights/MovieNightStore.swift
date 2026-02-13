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
@MainActor
final class MovieNightStore: ObservableObject {

    @Published private(set) var eventsByGroup: [String: [MovieNightEvent]] = [:]
    @Published private(set) var responsesByGroup: [String: [MovieNightResponse]] = [:]
    @Published private(set) var isLoaded: Bool = false

    private let persistence = MovieNightLocalPersistence()

    init() {
        Task { @MainActor in
            let snapshot = await persistence.load()
            self.eventsByGroup = snapshot.eventsByGroup
            self.responsesByGroup = snapshot.responsesByGroup
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

        persist()
        return event
    }

    func updateEvent(
        groupId: String,
        eventId: UUID,
        proposedStart: Date? = nil,
        note: String?? = nil,
        status: MovieNightEvent.Status? = nil
    ) {
        guard var list = eventsByGroup[groupId], let idx = list.firstIndex(where: { $0.id == eventId }) else { return }

        var event = list[idx]
        if let proposedStart { event.proposedStart = proposedStart }
        if let status { event.status = status }
        if let note { event.note = note }
        event.updatedAt = .now

        list[idx] = event
        list.sort(by: { $0.proposedStart < $1.proposedStart })
        eventsByGroup[groupId] = list

        persist()
    }

    func deleteEvent(groupId: String, eventId: UUID) {
        if var list = eventsByGroup[groupId] {
            list.removeAll(where: { $0.id == eventId })
            eventsByGroup[groupId] = list
        }

        if var responses = responsesByGroup[groupId] {
            responses.removeAll(where: { $0.eventId == eventId })
            responsesByGroup[groupId] = responses
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
        persist()
    }

    // MARK: - Debug / Utilities

    func purgeAllLocalData() {
        eventsByGroup.removeAll()
        responsesByGroup.removeAll()

        Task { await persistence.deleteLocalFile() }

        // Persist the empty snapshot so the app state matches disk state even if file delete fails.
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        let snapshot = MovieNightLocalPersistence.Snapshot(
            schemaVersion: 1,
            savedAt: .now,
            eventsByGroup: eventsByGroup,
            responsesByGroup: responsesByGroup
        )

        Task {
            await persistence.save(snapshot)
        }
    }
}
