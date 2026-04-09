//
//  MovieNightStore+Writes.swift
//  filmfreaks
//
//  Split from MovieNightStore.swift (MOVIENIGHT-STORE-RESPONSIBILITY-SPLIT-1)
//

import Foundation

extension MovieNightStore {

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
}
