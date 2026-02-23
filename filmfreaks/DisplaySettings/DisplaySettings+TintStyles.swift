//
//  DisplaySettings+TintStyles.swift
//  filmfreaks
//
//  Central helpers for theme-consistent tint surfaces.
//  This removes hardcoded "blue" backgrounds and makes presets feel real.
//

internal import SwiftUI

extension DisplaySettings {

    /// Convenience: derive a background/stroke color from the current tint.
    /// Use this for subtle surfaces (chips, badges, button backgrounds) instead of hardcoded colors.
    func tint(_ opacity: Double) -> Color {
        tintColor.opacity(opacity)
    }

    /// Default "soft" tint surface used for chips/badges.
    var tintSoftBackground: Color { tint(0.12) }

    /// Even more subtle surface (e.g. secondary chips).
    var tintUltraSoftBackground: Color { tint(0.08) }

    /// Slightly stronger tint surface (e.g. primary action buttons).
    var tintActionBackground: Color { tint(0.16) }

    /// Used for small tag chips where 0.12 can feel a bit heavy.
    var tintChipBackground: Color { tint(0.10) }

    /// Subtle outline for tinted surfaces.
    var tintStroke: Color { tint(0.20) }

    /// Tinted glow/shadow accents.
    var tintShadowStrong: Color { tint(0.14) }
    var tintShadowSoft: Color { tint(0.08) }
}
