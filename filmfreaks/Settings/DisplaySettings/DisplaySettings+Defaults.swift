//
//  DisplaySettings+Defaults.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

import Foundation

extension DisplaySettings {

    // MARK: - Defaults

    static let defaultColorScheme: ColorSchemePreference = .system
    static let defaultAccentColor: AccentColorPreference = .system
    static let defaultFontDesign: FontDesignPreference = .system
    static let defaultUIDensity: UIDensity = .normal
    static let defaultCornerStyle: CornerStyle = .rounded
    static let defaultCardStyle: CardStyle = .cards
    static let defaultPosterGridDensity: PosterGridDensity = .normal

    // Liste: Sichtbarkeit (Defaults: Verhalten wie bisher = alles sichtbar)
    static let defaultShowRatings: Bool = true
    static let defaultShowTMDbRatingsInLists: Bool = true
    static let defaultRatingDisplayMode: RatingDisplayMode = .ratingAverage
    static let defaultRatingBadgeStyle: RatingBadgeStyle = .pill
    static let defaultShowMovieYearInLists: Bool = true
    static let defaultShowWatchedDate: Bool = true
    static let defaultShowWatchedLocation: Bool = true
    static let defaultShowSuggestedBy: Bool = true
    static let defaultShowPosterInCompactList: Bool = true
    static let defaultShowGroupActivityCard: Bool = true

    // MARK: - Reset

    func resetToDefaults() {
        applyDefaults()
    }

    func applyDefaults() {
        colorScheme = Self.defaultColorScheme
        accentColor = Self.defaultAccentColor
        fontDesign = Self.defaultFontDesign
        uiDensity = Self.defaultUIDensity

        cornerStyle = Self.defaultCornerStyle

        cardStyle = Self.defaultCardStyle
        posterGridDensity = Self.defaultPosterGridDensity

        showRatings = Self.defaultShowRatings
        showTMDbRatingsInLists = Self.defaultShowTMDbRatingsInLists
        ratingDisplayMode = Self.defaultRatingDisplayMode
        ratingBadgeStyle = Self.defaultRatingBadgeStyle
        showMovieYearInLists = Self.defaultShowMovieYearInLists
        showWatchedDate = Self.defaultShowWatchedDate
        showWatchedLocation = Self.defaultShowWatchedLocation
        showSuggestedBy = Self.defaultShowSuggestedBy
        showPosterInCompactList = Self.defaultShowPosterInCompactList

        showGroupActivityCard = Self.defaultShowGroupActivityCard
    }
}
