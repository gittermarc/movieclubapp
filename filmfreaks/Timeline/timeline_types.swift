//
//  timeline_types.swift
//  filmfreaks
//

import Foundation

enum TimelineFilterMode: String, CaseIterable, Identifiable {
    case year = "Jahr"
    case range = "Zeitraum"
    var id: Self { self }
}

enum TimelineTimeRange: String, CaseIterable, Identifiable {
    case last30 = "Letzte 30 Tage"
    case last90 = "Letzte 90 Tage"
    case thisYear = "Dieses Jahr"
    case all = "Gesamte Zeit"
    var id: Self { self }
}
