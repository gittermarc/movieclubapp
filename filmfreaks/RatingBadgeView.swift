//
//  RatingBadgeView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

/// Zentrale Badge-View für Rating-Durchschnitte (1–10) in Listen.
/// Sie entscheidet *nur* über das UI (Style), nicht über die Berechnung.
struct RatingBadgeView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let value: Double?
    var font: Font = .headline
    var isCompactContext: Bool = false
    var placeholder: String = "-"

    var body: some View {
        if let value {
            badge(for: value)
                .accessibilityLabel(Text(accessibilityText(for: value)))
        } else {
            Text(placeholder)
                .font(font)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Keine Bewertung"))
        }
    }

    private func accessibilityText(for value: Double) -> String {
        "Durchschnitt \(String(format: "%.1f", value))"
    }

    @ViewBuilder
    private func badge(for value: Double) -> some View {
        let text = String(format: "%.1f", value)

        switch displaySettings.ratingBadgeStyle {
        case .pill:
            Text(text)
                .font(font.monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(displaySettings.tintColor.opacity(isCompactContext ? 0.12 : 0.10))
                .clipShape(RoundedRectangle(cornerRadius: displaySettings.pillCornerRadius))

        case .compact:
            Text(text)
                .font(font.monospacedDigit())

        case .starAndNumber:
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(displaySettings.tintColor)
                Text(text)
                    .foregroundStyle(.primary)
            }
            .font(font.monospacedDigit())

        case .averagePrefix:
            HStack(spacing: 4) {
                Text("Ø")
                    .foregroundStyle(.secondary)
                Text(text)
                    .foregroundStyle(.primary)
            }
            .font(font.monospacedDigit())
        }
    }
}
