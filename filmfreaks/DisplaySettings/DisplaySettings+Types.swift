//
//  DisplaySettings+Types.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI

extension DisplaySettings {

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
        case indigo
        case purple
        case pink
        case red
        case orange
        case yellow
        case green
        case mint
        case teal
        case cyan
        case gray
        case brown

        var id: Self { self }

        var label: String {
            switch self {
            case .system: return "Standard"
            case .blue:   return "Blau"
            case .indigo: return "Indigo"
            case .purple: return "Lila"
            case .pink:   return "Pink"
            case .red:    return "Rot"
            case .orange: return "Orange"
            case .yellow: return "Gelb"
            case .green:  return "Grün"
            case .teal:   return "Türkis"
            case .mint:   return "Mint"
            case .cyan:   return "Cyan"
            case .gray:   return "Grau"
            case .brown:  return "Braun"
            }
        }

        var color: Color {
            switch self {
            case .system: return .accentColor
            case .blue:   return .blue
            case .indigo: return .indigo
            case .purple: return .purple
            case .pink:   return .pink
            case .red:    return .red
            case .orange: return .orange
            case .yellow: return .yellow
            case .green:  return .green
            case .teal:   return .teal
            case .mint:   return .mint
            case .cyan:   return .cyan
            case .gray:   return .gray
            case .brown:  return .brown
            }
        }
    }

    /// App-weite Schrift-Variante (System / Rounded / Serif).
    /// Hinweis: Wir bleiben bewusst bei System-Designs, damit Dynamic Type & Layout stabil bleiben.
    enum FontDesignPreference: String, CaseIterable, Identifiable {
        case system
        case rounded
        case serif

        var id: Self { self }

        var label: String {
            switch self {
            case .system:  return "System"
            case .rounded: return "Rounded"
            case .serif:   return "Serif"
            }
        }

        var design: Font.Design {
            switch self {
            case .system:  return .default
            case .rounded: return .rounded
            case .serif:   return .serif
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
            case .cozy:    return "Mehr Luft – wirkt entspannter & premium."
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

    /// Rundungs-Stil für UI-Elemente (Poster, Karten, Pills).
    enum CornerStyle: String, CaseIterable, Identifiable {
        case square
        case rounded
        case extraRounded

        var id: Self { self }

        var label: String {
            switch self {
            case .square:       return "Kantig"
            case .rounded:      return "Rund"
            case .extraRounded: return "Extra"
            }
        }

        var shortHint: String {
            switch self {
            case .square:       return "Gerade Kanten – clean & minimal."
            case .rounded:      return "Der aktuelle Look – ausgewogen."
            case .extraRounded: return "Weicher & verspielter – more ‚cozy‘."
            }
        }
    }
}
