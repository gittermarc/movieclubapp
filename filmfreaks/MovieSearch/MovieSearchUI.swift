//
//  MovieSearchUI.swift
//  filmfreaks
//

internal import SwiftUI

/// Gemeinsame UI-Konstanten für MovieSearch (damit die extrahierten Subviews keine privaten Werte aus MovieSearchView brauchen).
enum MovieSearchUI {
    static let posterWidth: CGFloat = 76
    static let posterHeight: CGFloat = 114 // ~2:3
    static let cardCorner: CGFloat = 14

    // Empfehlungen
    static let recPosterWidth: CGFloat = 120
    static let recPosterHeight: CGFloat = 178 // ~2:3
    static let recCardCorner: CGFloat = 16
}
