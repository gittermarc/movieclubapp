//
//  DisplaySettings.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI
import Foundation
import Combine

/// Zentrale Darstellungseinstellungen (lokal via UserDefaults gespeichert).
/// P0: Farbschema + Akzentfarbe + Sichtbarkeit in Listen (Bewertung/Metadaten).
/// P0.1: UI-Dichte (Kompakt / Normal / Cozy) als zentrale Layout-Metrik.
final class DisplaySettings: ObservableObject {

    // MARK: - Storage Keys

    private enum Keys {
        static let colorScheme = "DisplaySettings_ColorScheme"
        static let accentColor = "DisplaySettings_AccentColor"

        static let uiDensity = "DisplaySettings_UIDensity"

        static let cardStyle = "DisplaySettings_CardStyle"
        static let posterGridDensity = "DisplaySettings_PosterGridDensity"

        static let showRatings = "DisplaySettings_ShowRatings"
        static let showTMDbRatingsInLists = "DisplaySettings_ShowTMDbRatingsInLists"
        static let ratingDisplayMode = "DisplaySettings_RatingDisplayMode"
        static let showWatchedDate = "DisplaySettings_ShowWatchedDate"
        static let showWatchedLocation = "DisplaySettings_ShowWatchedLocation"
        static let showSuggestedBy = "DisplaySettings_ShowSuggestedBy"

        static let showPosterInCompactList = "DisplaySettings_ShowPosterInCompactList"
    }

    private let defaults: UserDefaults

    // MARK: - Public Enums

    enum ColorSchemePreference: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: Self { self }

        var label: String {
            switch self {
            case .system: return "System"
            case .light:  return "Hell"
            case .dark:   return "Dunkel"
            }
        }

        var resolved: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    enum AccentColorPreference: String, CaseIterable, Identifiable {
        case system
        case blue
        case purple
        case pink
        case red
        case orange
        case green
        case teal
        case indigo

        var id: Self { self }

        var label: String {
            switch self {
            case .system: return "Standard"
            case .blue:   return "Blau"
            case .purple: return "Lila"
            case .pink:   return "Pink"
            case .red:    return "Rot"
            case .orange: return "Orange"
            case .green:  return "Grün"
            case .teal:   return "Türkis"
            case .indigo: return "Indigo"
            }
        }

        var color: Color {
            switch self {
            case .system: return .accentColor
            case .blue:   return .blue
            case .purple: return .purple
            case .pink:   return .pink
            case .red:    return .red
            case .orange: return .orange
            case .green:  return .green
            case .teal:   return .teal
            case .indigo: return .indigo
            }
        }
    }

    /// Globaler "Layout-Spacing" Schalter.
    /// Idee: Views greifen nur noch auf `displaySettings.metrics.*` zu.
    enum UIDensity: String, CaseIterable, Identifiable {
        case compact
        case normal
        case cozy

        var id: Self { self }

        var label: String {
            switch self {
            case .compact: return "Kompakt"
            case .normal:  return "Normal"
            case .cozy:    return "Cozy"
            }
        }

        var shortHint: String {
            switch self {
            case .compact: return "Weniger Luft – mehr Inhalt auf dem Screen."
            case .normal:  return "Ausgewogen – entspricht dem aktuellen Standard."
            case .cozy:    return "Mehr Luft – wirkt entspannter & "
                + "premium." // split to avoid long line
            }
        }
    }

    /// Listen: „Karten“ (mit Background + Shadow) oder „Plain“ (System-List-Feeling).
    enum CardStyle: String, CaseIterable, Identifiable {
        case cards
        case plain

        var id: Self { self }

        var label: String {
            switch self {
            case .cards: return "Cards"
            case .plain: return "Plain"
            }
        }

        var shortHint: String {
            switch self {
            case .cards: return "Mehr ‚Premium‘ – Karten mit leichtem Schatten."
            case .plain: return "Weniger Chrome – klassisches Listen-Layout."
            }
        }
    }

    /// Dichte der Cover-Grid Ansicht (Poster-Grid).
    enum PosterGridDensity: String, CaseIterable, Identifiable {
        case small
        case normal
        case large

        var id: Self { self }

        var label: String {
            switch self {
            case .small:  return "Klein"
            case .normal: return "Normal"
            case .large:  return "Groß"
            }
        }

        var shortHint: String {
            switch self {
            case .small:  return "Mehr Poster pro Zeile."
            case .normal: return "Ausgewogen – entspricht dem aktuellen Standard."
            case .large:  return "Weniger Poster, dafür schöner groß."
            }
        }
    }

    // MARK: - Layout Metrics

    /// Zentrale Spacing-Konstanten, abgeleitet aus `uiDensity`.
    struct LayoutMetrics: Equatable {
        let density: UIDensity

        // Reihen
        var rowPadding: CGFloat {
            switch density {
            case .compact: return 8
            case .normal:  return 10
            case .cozy:    return 12
            }
        }

        var rowHStackSpacing: CGFloat {
            switch density {
            case .compact: return 10
            case .normal:  return 12
            case .cozy:    return 14
            }
        }

        /// Abstand *zwischen* Karten (z.B. movieRow). (das ist der "Card-Spacing" Effekt)
        var cardVerticalSpacing: CGFloat {
            switch density {
            case .compact: return 2
            case .normal:  return 4
            case .cozy:    return 6
            }
        }

        // Kompakte Liste
        var compactRowVerticalPadding: CGFloat {
            switch density {
            case .compact: return 4
            case .normal:  return 6
            case .cozy:    return 8
            }
        }

        var compactRowHStackSpacing: CGFloat {
            switch density {
            case .compact: return 10
            case .normal:  return 12
            case .cozy:    return 14
            }
        }

        // Chips
        var chipHorizontalPadding: CGFloat {
            switch density {
            case .compact: return 8
            case .normal:  return 10
            case .cozy:    return 12
            }
        }

        var chipVerticalPadding: CGFloat {
            switch density {
            case .compact: return 6
            case .normal:  return 8
            case .cozy:    return 10
            }
        }

        var chipContentSpacing: CGFloat {
            switch density {
            case .compact: return 6
            case .normal:  return 8
            case .cozy:    return 10
            }
        }

        // Cards / Container (Sort/Filter Bar, Preview Card)
        var cardPadding: CGFloat {
            switch density {
            case .compact: return 8
            case .normal:  return 10
            case .cozy:    return 12
            }
        }

        var cardInnerSpacing: CGFloat {
            switch density {
            case .compact: return 6
            case .normal:  return 8
            case .cozy:    return 10
            }
        }

        // Context Bar
        var contextBarHorizontalPadding: CGFloat {
            switch density {
            case .compact: return 10
            case .normal:  return 12
            case .cozy:    return 14
            }
        }

        var contextBarVerticalPadding: CGFloat {
            switch density {
            case .compact: return 6
            case .normal:  return 8
            case .cozy:    return 10
            }
        }

        var contextBarItemSpacing: CGFloat {
            switch density {
            case .compact: return 8
            case .normal:  return 10
            case .cozy:    return 12
            }
        }

        var contextBarDividerVerticalPadding: CGFloat {
            switch density {
            case .compact: return 4
            case .normal:  return 6
            case .cozy:    return 8
            }
        }
    }

    /// Layout-Metriken speziell für das Poster-Grid.
    struct PosterGridMetrics: Equatable {
        let density: PosterGridDensity

        var minColumnWidth: CGFloat {
            switch density {
            case .small:  return 90
            case .normal: return 110
            case .large:  return 140
            }
        }

        var cellHeight: CGFloat {
            switch density {
            case .small:  return 140
            case .normal: return 170
            case .large:  return 220
            }
        }

        var spacing: CGFloat {
            switch density {
            case .small:  return 10
            case .normal: return 12
            case .large:  return 14
            }
        }
    }

    // MARK: - Persisted Properties

    @Published var colorScheme: ColorSchemePreference {
        didSet { defaults.set(colorScheme.rawValue, forKey: Keys.colorScheme) }
    }

    @Published var accentColor: AccentColorPreference {
        didSet { defaults.set(accentColor.rawValue, forKey: Keys.accentColor) }
    }

    @Published var uiDensity: UIDensity {
        didSet { defaults.set(uiDensity.rawValue, forKey: Keys.uiDensity) }
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

    // MARK: - Derived

    var preferredColorScheme: ColorScheme? { colorScheme.resolved }
    var tintColor: Color { accentColor.color }

    var metrics: LayoutMetrics { .init(density: uiDensity) }

    var posterGridMetrics: PosterGridMetrics { .init(density: posterGridDensity) }

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let schemeRaw = defaults.string(forKey: Keys.colorScheme) ?? ColorSchemePreference.system.rawValue
        self.colorScheme = ColorSchemePreference(rawValue: schemeRaw) ?? .system

        let accentRaw = defaults.string(forKey: Keys.accentColor) ?? AccentColorPreference.system.rawValue
        self.accentColor = AccentColorPreference(rawValue: accentRaw) ?? .system

        let densityRaw = defaults.string(forKey: Keys.uiDensity) ?? UIDensity.normal.rawValue
        self.uiDensity = UIDensity(rawValue: densityRaw) ?? .normal

        let cardRaw = defaults.string(forKey: Keys.cardStyle) ?? CardStyle.cards.rawValue
        self.cardStyle = CardStyle(rawValue: cardRaw) ?? .cards

        let gridRaw = defaults.string(forKey: Keys.posterGridDensity) ?? PosterGridDensity.normal.rawValue
        self.posterGridDensity = PosterGridDensity(rawValue: gridRaw) ?? .normal

        // Defaults: Verhalten wie heute (alles sichtbar)
        self.showRatings = defaults.object(forKey: Keys.showRatings) as? Bool ?? true

        // Defaults: TMDb-Fallback in Listen ist an (wie bisher)
        self.showTMDbRatingsInLists = defaults.object(forKey: Keys.showTMDbRatingsInLists) as? Bool ?? true

        let modeRaw = defaults.string(forKey: Keys.ratingDisplayMode) ?? RatingDisplayMode.ratingAverage.rawValue
        self.ratingDisplayMode = RatingDisplayMode(rawValue: modeRaw) ?? .ratingAverage

        self.showWatchedDate = defaults.object(forKey: Keys.showWatchedDate) as? Bool ?? true
        self.showWatchedLocation = defaults.object(forKey: Keys.showWatchedLocation) as? Bool ?? true
        self.showSuggestedBy = defaults.object(forKey: Keys.showSuggestedBy) as? Bool ?? true
        self.showPosterInCompactList = defaults.object(forKey: Keys.showPosterInCompactList) as? Bool ?? true
    }

    // MARK: - Reset

    func resetToDefaults() {
        colorScheme = .system
        accentColor = .system
        uiDensity = .normal

        cardStyle = .cards
        posterGridDensity = .normal

        showRatings = true
        showTMDbRatingsInLists = true
        ratingDisplayMode = .ratingAverage
        showWatchedDate = true
        showWatchedLocation = true
        showSuggestedBy = true
        showPosterInCompactList = true
    }
}
