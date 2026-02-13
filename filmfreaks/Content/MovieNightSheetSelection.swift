//
//  MovieNightSheetSelection.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// Selection payload for presenting `MovieNightDetailSheet` via `.sheet(item:)`.
struct MovieNightSheetSelection: Identifiable, Hashable {
    let groupId: String
    let id: UUID

    init(groupId: String, eventId: UUID) {
        self.groupId = groupId
        self.id = eventId
    }
}
