//
//  RatingBadgeStyle.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

import Foundation

/// Legt fest, wie der Durchschnitt (1–10) in Listen als Badge gerendert wird.
/// Rein visuell – keine Logikänderung, welcher Wert ausgewählt wird.
enum RatingBadgeStyle: String, CaseIterable, Identifiable, Codable {
    case pill
    case compact
    case starAndNumber
    case averagePrefix

    var id: Self { self }

    var label: String {
        switch self {
        case .pill: return "Pill"
        case .compact: return "Kompakt"
        case .starAndNumber: return "Star + Zahl"
        case .averagePrefix: return "Ø 8.6"
        }
    }

    var helpText: String {
        switch self {
        case .pill:
            return "Wie bisher: Zahl als Pill mit leichtem Hintergrund."
        case .compact:
            return "Sehr clean: nur die Zahl – ohne Badge-Chrome."
        case .starAndNumber:
            return "Etwas info-rich: Star-Icon plus Zahl."
        case .averagePrefix:
            return "Zeigt explizit den Durchschnitt: Ø + Zahl."
        }
    }
}
