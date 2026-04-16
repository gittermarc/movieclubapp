//
//  ContentTypes.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI


nonisolated enum MovieListMode: String, CaseIterable, Identifiable, Sendable {
    case watched = "Gesehen"
    case backlog = "Backlog"

    var id: Self { self }
}


nonisolated enum MovieSortOption: String, CaseIterable, Identifiable, Sendable {
    case dateNewest = "Zuletzt gesehen"
    case dateOldest = "Früheste zuerst"
    case ratingHigh = "Bewertung (hoch)"
    case ratingLow = "Bewertung (niedrig)"
    case titleAZ = "Titel A–Z"
    case titleZA = "Titel Z–A"

    var id: Self { self }
}


nonisolated enum MovieViewStyle: String, CaseIterable, Identifiable, Sendable {
    case posterGrid = "Cover-Grid"
    case cards = "Details"
    case compactList = "Liste (kompakt)"

    var id: Self { self }

    var icon: String {
        switch self {
        case .posterGrid: return "rectangle.grid.2x2"
        case .cards: return "rectangle.grid.1x2"
        case .compactList: return "list.bullet"
        }
    }
}
