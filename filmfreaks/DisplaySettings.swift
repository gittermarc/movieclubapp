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
final class DisplaySettings: ObservableObject {

    // MARK: - Storage Keys

    private enum Keys {
        static let colorScheme = "DisplaySettings_ColorScheme"
        static let accentColor = "DisplaySettings_AccentColor"

        static let showRatings = "DisplaySettings_ShowRatings"
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

    // MARK: - Persisted Properties

    @Published var colorScheme: ColorSchemePreference {
        didSet { defaults.set(colorScheme.rawValue, forKey: Keys.colorScheme) }
    }

    @Published var accentColor: AccentColorPreference {
        didSet { defaults.set(accentColor.rawValue, forKey: Keys.accentColor) }
    }

    // Liste: Sichtbarkeit
    @Published var showRatings: Bool {
        didSet { defaults.set(showRatings, forKey: Keys.showRatings) }
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

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let schemeRaw = defaults.string(forKey: Keys.colorScheme) ?? ColorSchemePreference.system.rawValue
        self.colorScheme = ColorSchemePreference(rawValue: schemeRaw) ?? .system

        let accentRaw = defaults.string(forKey: Keys.accentColor) ?? AccentColorPreference.system.rawValue
        self.accentColor = AccentColorPreference(rawValue: accentRaw) ?? .system

        // Defaults: Verhalten wie heute (alles sichtbar)
        self.showRatings = defaults.object(forKey: Keys.showRatings) as? Bool ?? true

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

        showRatings = true
        ratingDisplayMode = .ratingAverage
        showWatchedDate = true
        showWatchedLocation = true
        showSuggestedBy = true
        showPosterInCompactList = true
    }
}
