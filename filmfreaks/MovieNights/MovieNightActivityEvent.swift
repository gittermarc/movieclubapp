//
//  MovieNightActivityEvent.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// Activity stream events for movie night planning.
///
/// P2: Local-only. Will later be synced via CloudKit.
struct MovieNightActivityEvent: Identifiable, Hashable, Codable, Sendable {

    enum Kind: String, Codable, Sendable {
        case proposed
        case responded
        case statusChanged
        case deleted
    }

    var id: UUID = UUID()

    /// Group scope. For local-only usage, this can be an empty string.
    var groupId: String

    var kind: Kind
    var createdAt: Date

    /// The referenced movie night.
    var eventId: UUID
    var eventStart: Date

    /// Who triggered the activity.
    var actorUserId: UUID
    var actorName: String

    /// Optional payload (depends on kind).
    var decision: MovieNightResponse.Decision?
    var newStatus: MovieNightEvent.Status?
    var note: String?

    // MARK: - Convenience

    var systemImage: String {
        switch kind {
        case .proposed: return "calendar.badge.plus"
        case .responded: return "checkmark.seal"
        case .statusChanged: return "arrow.triangle.2.circlepath"
        case .deleted: return "trash"
        }
    }

    var titleText: String {
        switch kind {
        case .proposed:
            return "Filmabend vorgeschlagen"
        case .responded:
            switch decision {
            case .accepted: return "Zusage"
            case .declined: return "Absage"
            case .pending, .none: return "Antwort geändert"
            }
        case .statusChanged:
            if newStatus == .scheduled { return "Filmabend geplant" }
            if newStatus == .cancelled { return "Filmabend abgesagt" }
            return "Filmabend aktualisiert"
        case .deleted:
            return "Vorschlag gelöscht"
        }
    }

    var subtitleText: String {
        let time = Self.dateTimeFormatter.string(from: eventStart)
        switch kind {
        case .proposed:
            return "von \(actorName) · \(time)"
        case .responded:
            return "\(actorName) · \(time)"
        case .statusChanged:
            return "\(actorName) · \(time)"
        case .deleted:
            return "von \(actorName) · \(time)"
        }
    }

    private static let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE, d. MMM · HH:mm")
        return df
    }()
}
