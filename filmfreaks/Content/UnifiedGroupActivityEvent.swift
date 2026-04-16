//
//  UnifiedGroupActivityEvent.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// Unified activity event model used for teaser + full group activity feed.
///
/// - Movies/Ratings are derived via `GroupActivityEvent`.
/// - Movie nights use real activity events (`MovieNightActivityEvent`).
struct UnifiedGroupActivityEvent: Identifiable, Hashable, Sendable {

    enum Kind: String, Codable, Sendable {
        case movieAdded
        case movieRated
        case movieNightProposed
        case movieNightResponded
        case movieNightStatusChanged
        case movieNightDeleted
    }

    enum Payload: Hashable, Sendable {
        case movie(GroupActivityEvent)
        case movieNight(MovieNightActivityEvent)
    }

    let id: String
    let kind: Kind
    let date: Date
    let payload: Payload

    init(movieEvent: GroupActivityEvent) {
        self.kind = (movieEvent.kind == .movieAdded) ? .movieAdded : .movieRated
        self.date = movieEvent.date
        self.payload = .movie(movieEvent)
        self.id = "m|\(movieEvent.id)"
    }

    init(movieNightActivity: MovieNightActivityEvent) {
        self.kind = Self.mapNightKind(movieNightActivity.kind)
        self.date = movieNightActivity.createdAt
        self.payload = .movieNight(movieNightActivity)
        self.id = "n|\(movieNightActivity.id.uuidString.lowercased())"
    }

    private static func mapNightKind(_ kind: MovieNightActivityEvent.Kind) -> Kind {
        switch kind {
        case .proposed: return .movieNightProposed
        case .responded: return .movieNightResponded
        case .statusChanged: return .movieNightStatusChanged
        case .deleted: return .movieNightDeleted
        }
    }
}

extension UnifiedGroupActivityEvent {
    var movieEvent: GroupActivityEvent? {
        if case .movie(let e) = payload { return e }
        return nil
    }

    var movieNightEvent: MovieNightActivityEvent? {
        if case .movieNight(let e) = payload { return e }
        return nil
    }
}


extension UnifiedGroupActivityEvent {
    var actorUserId: UUID? {
        switch payload {
        case .movie(let event):
            return event.actorId
        case .movieNight(let event):
            return event.actorUserId
        }
    }

    var actorDisplayName: String? {
        switch payload {
        case .movie(let event):
            return event.actorName
        case .movieNight(let event):
            return event.actorName
        }
    }
}
