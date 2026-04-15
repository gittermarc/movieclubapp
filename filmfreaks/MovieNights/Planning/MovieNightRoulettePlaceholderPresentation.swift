//
//  MovieNightRoulettePlaceholderPresentation.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

/// Presentation helpers for the roulette placeholder shown in PR 1.
enum MovieNightRoulettePlaceholderPresentation {

    static func groupName(from rawGroupName: String?) -> String {
        let trimmed = (rawGroupName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "deiner Gruppe" : trimmed
    }

    static func introText(for rawGroupName: String?) -> String {
        let groupName = groupName(from: rawGroupName)
        return "Bald kannst du hier für \(groupName) einen Film zufällig aus dem Backlog oder aus einer kuratierten Auswahl bestimmen."
    }

    static let highlights: [Highlight] = [
        Highlight(
            title: "Backlog oder Vorauswahl",
            message: "Roulette soll später wahlweise aus euren Backlog-Filmen oder aus bewusst zusammengestellten Sets ziehen.",
            systemImage: "film.stack"
        ),
        Highlight(
            title: "Sauberer Einstieg",
            message: "Der neue Planning-Hub trennt Kalender und Roulette klar, ohne vorhandene Filmabend-Flows umzubauen.",
            systemImage: "square.grid.2x2"
        ),
        Highlight(
            title: "Nächster Schritt",
            message: "Im nächsten PR kommt hier die echte Spin-Ansicht mit Kandidaten aus dem Gruppen-Backlog hinein.",
            systemImage: "sparkles"
        )
    ]

    struct Highlight: Equatable, Identifiable {
        let title: String
        let message: String
        let systemImage: String

        var id: String { title }
    }
}
