//
//  DisplaySettings+Presets.swift
//  filmfreaks
//
//  Created by Marc Fechner on 04.02.26.
//

internal import SwiftUI

extension DisplaySettings {

    // MARK: - Presets

    /// Thematische Presets für die App. Ein Preset setzt mehrere Einstellungen in einem Tap.
    enum AppearancePreset: String, CaseIterable, Identifiable {
        case blockbuster
        case filmNoir
        case festivalCut
        case neonNight

        var id: Self { self }

        var title: String {
            switch self {
            case .blockbuster: return "Blockbuster"
            case .filmNoir: return "Film Noir"
            case .festivalCut: return "Festival Cut"
            case .neonNight: return "Neon Night"
            }
        }

        var subtitle: String {
            switch self {
            case .blockbuster: return "Groß, warm, Kino-Feeling"
            case .filmNoir: return "Dunkel, minimal, kompromisslos"
            case .festivalCut: return "Hell, luftig, Arthouse-Vibe"
            case .neonNight: return "Modern, kontrastreich, Sci‑Fi"
            }
        }

        var systemImage: String {
            switch self {
            case .blockbuster: return "popcorn"
            case .filmNoir: return "moon.stars"
            case .festivalCut: return "ticket.fill"
            case .neonNight: return "sparkles"
            }
        }

        /// Die vollständige Konfiguration, die dieses Preset setzt.
        var configuration: PresetConfiguration {
            switch self {
            case .blockbuster:
                return PresetConfiguration(
                    colorScheme: .system,
                    accentColor: .orange,
                    fontDesign: .rounded,
                    uiDensity: .cozy,
                    cardStyle: .cards,
                    posterGridDensity: .large,
                    showRatings: true,
                    showTMDbRatingsInLists: true,
                    ratingDisplayMode: .ratingAverage,
                    showMovieYearInLists: true,
                    showWatchedDate: true,
                    showWatchedLocation: true,
                    showSuggestedBy: true,
                    showPosterInCompactList: true
                )

            case .filmNoir:
                return PresetConfiguration(
                    colorScheme: .dark,
                    accentColor: .gray,
                    fontDesign: .serif,
                    uiDensity: .compact,
                    cardStyle: .plain,
                    posterGridDensity: .normal,
                    showRatings: true,
                    showTMDbRatingsInLists: false,
                    ratingDisplayMode: .fazitAverage,
                    showMovieYearInLists: true,
                    showWatchedDate: true,
                    showWatchedLocation: false,
                    showSuggestedBy: false,
                    showPosterInCompactList: false
                )

            case .festivalCut:
                return PresetConfiguration(
                    colorScheme: .light,
                    accentColor: .teal,
                    fontDesign: .serif,
                    uiDensity: .cozy,
                    cardStyle: .cards,
                    posterGridDensity: .normal,
                    showRatings: true,
                    showTMDbRatingsInLists: true,
                    ratingDisplayMode: .fazitAverage,
                    showMovieYearInLists: true,
                    showWatchedDate: true,
                    showWatchedLocation: true,
                    showSuggestedBy: true,
                    showPosterInCompactList: true
                )

            case .neonNight:
                return PresetConfiguration(
                    colorScheme: .dark,
                    accentColor: .cyan,
                    fontDesign: .system,
                    uiDensity: .normal,
                    cardStyle: .cards,
                    posterGridDensity: .small,
                    showRatings: true,
                    showTMDbRatingsInLists: true,
                    ratingDisplayMode: .ratingAverage,
                    showMovieYearInLists: true,
                    showWatchedDate: true,
                    showWatchedLocation: true,
                    showSuggestedBy: true,
                    showPosterInCompactList: true
                )
            }
        }
    }

    /// Ein Snapshot aller Appearance-relevanten Einstellungen.
    /// Wichtig: Wenn wir neue Settings hinzufügen, sollten sie auch hier landen,
    /// damit Presets konsistent bleiben.
    struct PresetConfiguration: Equatable {
        let colorScheme: ColorSchemePreference
        let accentColor: AccentColorPreference
        let fontDesign: FontDesignPreference
        let uiDensity: UIDensity
        let cardStyle: CardStyle
        let posterGridDensity: PosterGridDensity

        let showRatings: Bool
        let showTMDbRatingsInLists: Bool
        let ratingDisplayMode: RatingDisplayMode
        let showMovieYearInLists: Bool
        let showWatchedDate: Bool
        let showWatchedLocation: Bool
        let showSuggestedBy: Bool
        let showPosterInCompactList: Bool
    }

    /// Welches Preset passt exakt zu den aktuellen Einstellungen? (Wenn keins passt: `nil` = individuell)
    var currentPreset: AppearancePreset? {
        let current = currentPresetConfiguration
        return AppearancePreset.allCases.first(where: { $0.configuration == current })
    }

    func applyPreset(_ preset: AppearancePreset) {
        let c = preset.configuration

        colorScheme = c.colorScheme
        accentColor = c.accentColor
        fontDesign = c.fontDesign
        uiDensity = c.uiDensity

        cardStyle = c.cardStyle
        posterGridDensity = c.posterGridDensity

        showRatings = c.showRatings
        showTMDbRatingsInLists = c.showTMDbRatingsInLists
        ratingDisplayMode = c.ratingDisplayMode
        showMovieYearInLists = c.showMovieYearInLists
        showWatchedDate = c.showWatchedDate
        showWatchedLocation = c.showWatchedLocation
        showSuggestedBy = c.showSuggestedBy
        showPosterInCompactList = c.showPosterInCompactList
    }

    private var currentPresetConfiguration: PresetConfiguration {
        PresetConfiguration(
            colorScheme: colorScheme,
            accentColor: accentColor,
            fontDesign: fontDesign,
            uiDensity: uiDensity,
            cardStyle: cardStyle,
            posterGridDensity: posterGridDensity,
            showRatings: showRatings,
            showTMDbRatingsInLists: showTMDbRatingsInLists,
            ratingDisplayMode: ratingDisplayMode,
            showMovieYearInLists: showMovieYearInLists,
            showWatchedDate: showWatchedDate,
            showWatchedLocation: showWatchedLocation,
            showSuggestedBy: showSuggestedBy,
            showPosterInCompactList: showPosterInCompactList
        )
    }
}
