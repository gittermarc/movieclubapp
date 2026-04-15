//
//  MovieNightPlanningSection.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

/// Top-level areas inside the Movie Night planning hub.
enum MovieNightPlanningSection: String, CaseIterable, Identifiable {
    case calendar
    case roulette

    var id: String { rawValue }

    static var defaultSection: Self { .calendar }

    var title: String {
        switch self {
        case .calendar:
            return "Kalender"
        case .roulette:
            return "Roulette"
        }
    }

    var navigationTitle: String {
        switch self {
        case .calendar:
            return "Kalender"
        case .roulette:
            return "Filmroulette"
        }
    }
}
