//
//  DisplaySettings+Persistence.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

import Foundation

extension DisplaySettings {

    // MARK: - Load

    /// Lädt alle persistierten Werte aus `UserDefaults` und überschreibt die
    /// bereits gesetzten Default-Werte. (Keine Side-Effects, keine Writes.)
    func loadFromDefaults() {
        let schemeRaw = defaults.string(forKey: Keys.colorScheme) ?? Self.defaultColorScheme.rawValue
        self.colorScheme = ColorSchemePreference(rawValue: schemeRaw) ?? Self.defaultColorScheme

        let accentRaw = defaults.string(forKey: Keys.accentColor) ?? Self.defaultAccentColor.rawValue
        self.accentColor = AccentColorPreference(rawValue: accentRaw) ?? Self.defaultAccentColor

        let fontRaw = defaults.string(forKey: Keys.fontDesign) ?? Self.defaultFontDesign.rawValue
        self.fontDesign = FontDesignPreference(rawValue: fontRaw) ?? Self.defaultFontDesign

        let densityRaw = defaults.string(forKey: Keys.uiDensity) ?? Self.defaultUIDensity.rawValue
        self.uiDensity = UIDensity(rawValue: densityRaw) ?? Self.defaultUIDensity

        let cornerRaw = defaults.string(forKey: Keys.cornerStyle) ?? Self.defaultCornerStyle.rawValue
        self.cornerStyle = CornerStyle(rawValue: cornerRaw) ?? Self.defaultCornerStyle

        let cardRaw = defaults.string(forKey: Keys.cardStyle) ?? Self.defaultCardStyle.rawValue
        self.cardStyle = CardStyle(rawValue: cardRaw) ?? Self.defaultCardStyle

        let gridRaw = defaults.string(forKey: Keys.posterGridDensity) ?? Self.defaultPosterGridDensity.rawValue
        self.posterGridDensity = PosterGridDensity(rawValue: gridRaw) ?? Self.defaultPosterGridDensity

        self.showRatings = readBool(forKey: Keys.showRatings, defaultValue: Self.defaultShowRatings)
        self.showTMDbRatingsInLists = readBool(forKey: Keys.showTMDbRatingsInLists, defaultValue: Self.defaultShowTMDbRatingsInLists)

        let modeRaw = defaults.string(forKey: Keys.ratingDisplayMode) ?? Self.defaultRatingDisplayMode.rawValue
        self.ratingDisplayMode = RatingDisplayMode(rawValue: modeRaw) ?? Self.defaultRatingDisplayMode

        let badgeRaw = defaults.string(forKey: Keys.ratingBadgeStyle) ?? Self.defaultRatingBadgeStyle.rawValue
        self.ratingBadgeStyle = RatingBadgeStyle(rawValue: badgeRaw) ?? Self.defaultRatingBadgeStyle

        self.showMovieYearInLists = readBool(forKey: Keys.showMovieYearInLists, defaultValue: Self.defaultShowMovieYearInLists)

        self.showWatchedDate = readBool(forKey: Keys.showWatchedDate, defaultValue: Self.defaultShowWatchedDate)
        self.showWatchedLocation = readBool(forKey: Keys.showWatchedLocation, defaultValue: Self.defaultShowWatchedLocation)
        self.showSuggestedBy = readBool(forKey: Keys.showSuggestedBy, defaultValue: Self.defaultShowSuggestedBy)
        self.showPosterInCompactList = readBool(forKey: Keys.showPosterInCompactList, defaultValue: Self.defaultShowPosterInCompactList)

        self.showGroupActivityCard = readBool(forKey: Keys.showGroupActivityCard, defaultValue: Self.defaultShowGroupActivityCard)
    }

    // MARK: - Helpers

    private func readBool(forKey key: String, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
