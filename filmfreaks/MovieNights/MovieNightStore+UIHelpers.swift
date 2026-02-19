//
//  MovieNightStore+UIHelpers.swift
//  filmfreaks
//
//  Split from MovieNightStore.swift (P0.3)
//

import Foundation

extension MovieNightStore {

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
}
