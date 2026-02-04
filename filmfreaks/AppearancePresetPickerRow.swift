//
//  AppearancePresetPickerRow.swift
//  filmfreaks
//
//  Created by Marc Fechner on 04.02.26.
//

internal import SwiftUI

#if canImport(UIKit)
internal import UIKit
#endif

/// Horizontale Preset-Auswahl (Apple-Music-Vibe): 4 Karten, ein Tap setzt mehrere Appearance-Optionen.
struct AppearancePresetPickerRow: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: m.cardInnerSpacing + 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DisplaySettings.AppearancePreset.allCases) { preset in
                        AppearancePresetCard(
                            preset: preset,
                            isSelected: displaySettings.currentPreset == preset,
                            tintColor: displaySettings.tintColor,
                            cardPadding: m.cardPadding,
                            innerSpacing: m.cardInnerSpacing
                        ) {
                            apply(preset)
                        }
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }

            activeHintRow
        }
        .padding(.vertical, 4)
    }

    private var activeHintRow: some View {
        HStack(spacing: 8) {
            Text("Aktiv:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let active = displaySettings.currentPreset {
                Text(active.title)
                    .font(.footnote.weight(.semibold))
                Text("•")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(active.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Individuell")
                    .font(.footnote.weight(.semibold))
                Text("•")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Du hast dein eigenes Setup zusammengestellt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityLabel(accessibilityHintText)
    }

    private var accessibilityHintText: String {
        if let active = displaySettings.currentPreset {
            return "Aktives Preset: \(active.title). \(active.subtitle)."
        }
        return "Aktives Preset: Individuell."
    }

    private func apply(_ preset: DisplaySettings.AppearancePreset) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif

        withAnimation(.snappy) {
            displaySettings.applyPreset(preset)
        }
    }
}

// MARK: - Preset Card

private struct AppearancePresetCard: View {

    let preset: DisplaySettings.AppearancePreset
    let isSelected: Bool
    let tintColor: Color
    let cardPadding: CGFloat
    let innerSpacing: CGFloat
    let action: () -> Void

    private var config: DisplaySettings.PresetConfiguration { preset.configuration }
    private var accent: Color { config.accentColor.color }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: innerSpacing + 2) {
                headerRow

                Text(preset.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(preset.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                tagsRow
            }
            .padding(cardPadding + 4)
            .frame(width: 210, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.snappy(duration: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.title). \(preset.subtitle)")
        .accessibilityHint("Doppeltippen, um dieses Preset anzuwenden.")
    }

    private var borderColor: Color {
        if isSelected {
            return tintColor.opacity(0.95)
        }
        return Color.primary.opacity(0.08)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: preset.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)

            Spacer(minLength: 0)

            Circle()
                .fill(accent)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private var tagsRow: some View {
        HStack(spacing: 8) {
            PresetTag(text: config.colorScheme.label, tint: accent)
            PresetTag(text: config.uiDensity.label, tint: accent)
            PresetTag(text: config.cardStyle.label, tint: accent)
        }
    }
}

private struct PresetTag: View {

    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
