//
//  DisplaySettings.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI
import Combine
import Foundation

/// Zentrale Darstellungseinstellungen (lokal via UserDefaults gespeichert).
///
/// Hinweis: Die Datei enthält bewusst nur "Kern + Stored Properties".
/// Alles Weitere ist in `DisplaySettings+*.swift` Extensions gesplittet.
final class DisplaySettings: ObservableObject {

    // MARK: - Storage Keys

    /// Access-Level ist absichtlich nicht `private`, damit Split-Extensions in
    /// separaten Dateien darauf zugreifen können. Bitte nicht extern nutzen.
    enum Keys {
        static let colorScheme = "DisplaySettings_ColorScheme"
        static let accentColor = "DisplaySettings_AccentColor"

        static let fontDesign = "DisplaySettings_FontDesign"

        static let uiDensity = "DisplaySettings_UIDensity"

        static let cornerStyle = "DisplaySettings_CornerStyle"

        static let cardStyle = "DisplaySettings_CardStyle"
        static let posterGridDensity = "DisplaySettings_PosterGridDensity"

        static let showRatings = "DisplaySettings_ShowRatings"
        static let showTMDbRatingsInLists = "DisplaySettings_ShowTMDbRatingsInLists"
        static let ratingDisplayMode = "DisplaySettings_RatingDisplayMode"
        static let ratingBadgeStyle = "DisplaySettings_RatingBadgeStyle"
        static let showMovieYearInLists = "DisplaySettings_ShowMovieYearInLists"
        static let showWatchedDate = "DisplaySettings_ShowWatchedDate"
        static let showWatchedLocation = "DisplaySettings_ShowWatchedLocation"
        static let showSuggestedBy = "DisplaySettings_ShowSuggestedBy"

        static let showPosterInCompactList = "DisplaySettings_ShowPosterInCompactList"

        static let showGroupActivityCard = "DisplaySettings_ShowGroupActivityCard"
    }

    /// Access-Level ist absichtlich nicht `private`, damit Split-Extensions in
    /// separaten Dateien darauf zugreifen können.
    let defaults: UserDefaults

    // MARK: - Persisted Properties

    @Published var colorScheme: ColorSchemePreference {
        didSet { defaults.set(colorScheme.rawValue, forKey: Keys.colorScheme) }
    }

    @Published var accentColor: AccentColorPreference {
        didSet { defaults.set(accentColor.rawValue, forKey: Keys.accentColor) }
    }

    @Published var fontDesign: FontDesignPreference {
        didSet { defaults.set(fontDesign.rawValue, forKey: Keys.fontDesign) }
    }

    @Published var uiDensity: UIDensity {
        didSet { defaults.set(uiDensity.rawValue, forKey: Keys.uiDensity) }
    }

    /// Rundungs-Stil (Square / Rounded / Extra).
    @Published var cornerStyle: CornerStyle {
        didSet { defaults.set(cornerStyle.rawValue, forKey: Keys.cornerStyle) }
    }

    /// Card-Style für Listen (Karten vs. Plain).
    @Published var cardStyle: CardStyle {
        didSet { defaults.set(cardStyle.rawValue, forKey: Keys.cardStyle) }
    }

    /// Dichte für die Poster-Grid Ansicht.
    @Published var posterGridDensity: PosterGridDensity {
        didSet { defaults.set(posterGridDensity.rawValue, forKey: Keys.posterGridDensity) }
    }

    // Liste: Sichtbarkeit
    @Published var showRatings: Bool {
        didSet { defaults.set(showRatings, forKey: Keys.showRatings) }
    }

    /// Wenn aktiv, dürfen TMDb-Ratings als Fallback in Listen angezeigt werden
    /// (z.B. wenn die Gruppe noch keine Bewertung vergeben hat).
    @Published var showTMDbRatingsInLists: Bool {
        didSet { defaults.set(showTMDbRatingsInLists, forKey: Keys.showTMDbRatingsInLists) }
    }

    /// Welche Kennzahl wird als "Ø" angezeigt? (Bewertung vs Fazit)
    @Published var ratingDisplayMode: RatingDisplayMode {
        didSet { defaults.set(ratingDisplayMode.rawValue, forKey: Keys.ratingDisplayMode) }
    }

    /// Wie wird die Bewertungs-Kennzahl in Listen gerendert? (Pill / Compact / Star+Zahl / Ø)
    @Published var ratingBadgeStyle: RatingBadgeStyle {
        didSet { defaults.set(ratingBadgeStyle.rawValue, forKey: Keys.ratingBadgeStyle) }
    }

    /// Wenn deaktiviert, wird in Listen das Erscheinungsjahr nicht angezeigt.
    @Published var showMovieYearInLists: Bool {
        didSet { defaults.set(showMovieYearInLists, forKey: Keys.showMovieYearInLists) }
    }

    @Published var showWatchedDate: Bool {
        didSet { defaults.set(showWatchedDate, forKey: Keys.showWatchedDate) }
    }

    @Published var showWatchedLocation: Bool {
        didSet { defaults.set(showWatchedLocation, forKey: Keys.showWatchedLocation) }
    }

    @Published var showSuggestedBy: Bool {
        didSet { defaults.set(showSuggestedBy, forKey: Keys.showSuggestedBy) }
    }

    @Published var showPosterInCompactList: Bool {
        didSet { defaults.set(showPosterInCompactList, forKey: Keys.showPosterInCompactList) }
    }

    /// Wenn deaktiviert, wird der Aktivitätszugang in der Context-Bar ausgeblendet.
    @Published var showGroupActivityCard: Bool {
        didSet { defaults.set(showGroupActivityCard, forKey: Keys.showGroupActivityCard) }
    }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Setup: Erst stabile Defaults setzen, dann aus UserDefaults überschreiben.
        // (Property Observers feuern in `init` nicht, Verhalten bleibt wie zuvor.)
        self.colorScheme = Self.defaultColorScheme
        self.accentColor = Self.defaultAccentColor
        self.fontDesign = Self.defaultFontDesign
        self.uiDensity = Self.defaultUIDensity
        self.cornerStyle = Self.defaultCornerStyle
        self.cardStyle = Self.defaultCardStyle
        self.posterGridDensity = Self.defaultPosterGridDensity
        self.showRatings = Self.defaultShowRatings
        self.showTMDbRatingsInLists = Self.defaultShowTMDbRatingsInLists
        self.ratingDisplayMode = Self.defaultRatingDisplayMode
        self.ratingBadgeStyle = Self.defaultRatingBadgeStyle
        self.showMovieYearInLists = Self.defaultShowMovieYearInLists
        self.showWatchedDate = Self.defaultShowWatchedDate
        self.showWatchedLocation = Self.defaultShowWatchedLocation
        self.showSuggestedBy = Self.defaultShowSuggestedBy
        self.showPosterInCompactList = Self.defaultShowPosterInCompactList
        self.showGroupActivityCard = Self.defaultShowGroupActivityCard

        loadFromDefaults()
    }
}
