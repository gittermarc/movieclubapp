//
//  RatingDisplayMode.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

import Foundation

/// Legt fest, welcher Gruppen-Durchschnitt (1–10) in der UI angezeigt wird.
/// - ratingAverage: Durchschnitt aus den Kriterien (wie bisher)
/// - fazitAverage: Durchschnitt aus dem Fazit (1–10), mit Fallback auf ratingAverage für Legacy-Daten
nonisolated enum RatingDisplayMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case ratingAverage
    case fazitAverage

    var id: Self { self }

    var label: String {
        switch self {
        case .ratingAverage:
            return "Bewertung"
        case .fazitAverage:
            return "Fazit"
        }
    }

    var helpText: String {
        switch self {
        case .ratingAverage:
            return "Zeigt den Durchschnitt aus den Kriterien (normalisiert auf 1–10)."
        case .fazitAverage:
            return "Zeigt den Durchschnitt der Fazit-Wertung (1–10). Wenn bei alten Bewertungen kein Fazit vorhanden ist, fällt die App auf die Kriterien-Bewertung zurück."
        }
    }
}
