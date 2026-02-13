//
//  MovieNightResponse.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// A per-user response to a movie night proposal.
///
/// There should be at most one response per (eventId, userId).
/// P0: Local-only (persisted to JSON via `MovieNightLocalPersistence`).
struct MovieNightResponse: Identifiable, Codable, Equatable, Hashable {

    enum Decision: String, Codable, CaseIterable {
        case pending
        case accepted
        case declined
    }

    var eventId: UUID
    var userId: UUID
    var userName: String

    var decision: Decision
    var respondedAt: Date

    /// Stable composite ID, useful for SwiftUI Lists.
    var id: String { "\(eventId.uuidString)_\(userId.uuidString)" }

    private enum CodingKeys: String, CodingKey {
        case eventId
        case userId
        case userName
        case decision
        case respondedAt
    }

    init(
        eventId: UUID,
        userId: UUID,
        userName: String,
        decision: Decision,
        respondedAt: Date = .now
    ) {
        self.eventId = eventId
        self.userId = userId
        self.userName = userName
        self.decision = decision
        self.respondedAt = respondedAt
    }
}
