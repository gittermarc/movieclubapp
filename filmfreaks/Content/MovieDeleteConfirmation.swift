//
//  MovieDeleteConfirmation.swift
//  filmfreaks
//
//  Small helper model for "Are you sure?" delete prompts.
//

import Foundation

struct MovieDeleteConfirmation: Identifiable, Equatable {
    let id = UUID()

    /// The movies to delete (stable across list/grid reordering).
    let movieIds: [UUID]

    /// Optional titles for nicer copy in the alert.
    let movieTitles: [String]

    /// Whether the deletion targets the backlog list (vs watched).
    let isBacklog: Bool

    var alertTitle: String {
        if movieIds.count == 1 {
            return "Film löschen?"
        }
        return "\(movieIds.count) Filme löschen?"
    }

    var alertMessage: String {
        if movieIds.count == 1 {
            let title = movieTitles.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeTitle = (title?.isEmpty == false) ? title! : "Dieser Film"
            return "\u{201E}\(safeTitle)\u{201C} wird gelöscht. Diese Aktion kann nicht rückgängig gemacht werden."
        }
        return "\(movieIds.count) Filme werden gelöscht. Diese Aktion kann nicht rückgängig gemacht werden."
    }
}
