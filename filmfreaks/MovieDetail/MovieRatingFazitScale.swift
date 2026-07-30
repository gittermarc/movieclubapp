//
//  MovieRatingFazitScale.swift
//  filmfreaks
//
//  Shared presentation for the 1 to 10 final verdict scale.
//

internal import SwiftUI

enum MovieRatingFazitScale {

    static var gradientColors: [Color] {
        [
            color(for: 1),
            color(for: 3),
            color(for: 5),
            color(for: 7),
            color(for: 10),
        ]
    }

    static func color(for score: Int?) -> Color {
        guard let score else {
            return .secondary
        }

        let clampedScore = min(10, max(1, score))
        let progress = Double(clampedScore - 1) / 9.0
        let hue = progress * 0.33

        return Color(hue: hue, saturation: 0.82, brightness: 0.92)
    }

    static func scoreText(_ score: Int?) -> String {
        guard let score else {
            return "Nicht vergeben"
        }

        return "\(score) / 10"
    }
}
