//
//  MovieNightEvent.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// A proposed or scheduled movie night for a specific group.
///
/// P0: Local-only (persisted to JSON via `MovieNightLocalPersistence`).
struct MovieNightEvent: Identifiable, Codable, Equatable, Hashable {

    enum Status: String, Codable, CaseIterable, Sendable {
        case open
        case scheduled
        case cancelled
    }

    var id: UUID
    var groupId: String
    var proposedStart: Date

    var createdAt: Date
    var updatedAt: Date

    var proposerUserId: UUID
    var proposerName: String

    /// Optional movie picked from the current group backlog.
    var suggestedMovie: MovieNightMovieRef?

    var note: String?
    var status: Status

    init(
        id: UUID = UUID(),
        groupId: String,
        proposedStart: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        proposerUserId: UUID,
        proposerName: String,
        suggestedMovie: MovieNightMovieRef? = nil,
        note: String? = nil,
        status: Status = .open
    ) {
        self.id = id
        self.groupId = groupId
        self.proposedStart = proposedStart
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.proposerUserId = proposerUserId
        self.proposerName = proposerName
        self.suggestedMovie = suggestedMovie
        self.note = note
        self.status = status
    }
}

extension MovieNightEvent {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: proposedStart)
    }
}
