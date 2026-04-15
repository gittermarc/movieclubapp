//
//  MovieRouletteSource.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

enum MovieRouletteSource: String, CaseIterable, Identifiable {
    case backlog
    case preset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog:
            return "Backlog"
        case .preset:
            return "Auswahl"
        }
    }
}
