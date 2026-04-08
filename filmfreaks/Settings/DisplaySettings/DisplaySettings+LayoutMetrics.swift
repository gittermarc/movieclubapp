//
//  DisplaySettings+LayoutMetrics.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI

extension DisplaySettings {

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

    // MARK: - Derived

    var preferredColorScheme: ColorScheme? { colorScheme.resolved }
    var tintColor: Color { accentColor.color }

    var preferredFontDesign: Font.Design { fontDesign.design }

    var metrics: LayoutMetrics { .init(density: uiDensity) }

    var posterGridMetrics: PosterGridMetrics { .init(density: posterGridDensity) }

    var posterCornerRadius: CGFloat {
        switch cornerStyle {
        case .square:       return 0
        case .rounded:      return 8
        case .extraRounded: return 12
        }
    }

    var cardCornerRadius: CGFloat {
        switch cornerStyle {
        case .square:       return 0
        case .rounded:      return 12
        case .extraRounded: return 16
        }
    }

    var pillCornerRadius: CGFloat {
        switch cornerStyle {
        case .square:       return 0
        case .rounded:      return 8
        case .extraRounded: return 12
        }
    }
}
