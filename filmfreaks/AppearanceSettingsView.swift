//
//  AppearanceSettingsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.02.26.
//

internal import SwiftUI

struct AppearanceSettingsView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    private var densityHintText: String {
        displaySettings.uiDensity.shortHint
    }

    var body: some View {
        List {

            // Presets
            Section {
                AppearancePresetPickerRow()
                    .environmentObject(displaySettings)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Presets")
            } footer: {
                Text("Ein Tap setzt mehrere Optionen. Danach kannst du natürlich weiter feinjustieren – wie ein Director’s Cut, nur ohne 3 Stunden Laufzeit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Preview
            Section {
                AppearancePreviewCard()
                    .environmentObject(displaySettings)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Vorschau")
            }

            // Theme
            Section("Farben") {
                Picker("Farbschema", selection: $displaySettings.colorScheme) {
                    ForEach(DisplaySettings.ColorSchemePreference.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                AccentColorGridPicker(selection: $displaySettings.accentColor)
            }

            // Typography
            Section("Typografie") {
                Picker("Schriftstil", selection: $displaySettings.fontDesign) {
                    ForEach(DisplaySettings.FontDesignPreference.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                FontDesignPreviewCard(design: displaySettings.preferredFontDesign)
            }

            // Layout
            Section("Layout") {
                Picker("UI-Dichte", selection: $displaySettings.uiDensity) {
                    ForEach(DisplaySettings.UIDensity.allCases) { density in
                        Text(density.label).tag(density)
                    }
                }
                .pickerStyle(.segmented)

                Text(densityHintText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Picker("Card-Style", selection: $displaySettings.cardStyle) {
                    ForEach(DisplaySettings.CardStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(displaySettings.cardStyle.shortHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Picker("Grid-Dichte", selection: $displaySettings.posterGridDensity) {
                    ForEach(DisplaySettings.PosterGridDensity.allCases) { density in
                        Text(density.label).tag(density)
                    }
                }
                .pickerStyle(.segmented)

                Text(displaySettings.posterGridDensity.shortHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            // List visibility
            Section("Listen & Inhalte") {
                Toggle("Bewertung anzeigen", isOn: $displaySettings.showRatings)

                if displaySettings.showRatings {
                    Picker("Durchschnitt", selection: $displaySettings.ratingDisplayMode) {
                        ForEach(RatingDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("TMDb-Rating in Listen anzeigen", isOn: $displaySettings.showTMDbRatingsInLists)

                    Text("Wenn in der Gruppe noch keine Bewertung vorhanden ist, kann stattdessen das TMDb-Rating als Fallback angezeigt werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)

                    Text(displaySettings.ratingDisplayMode.helpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                Toggle("Gesehen-Datum anzeigen", isOn: $displaySettings.showWatchedDate)
                Toggle("Ort anzeigen", isOn: $displaySettings.showWatchedLocation)
                Toggle("„Vorgeschlagen von“ anzeigen", isOn: $displaySettings.showSuggestedBy)

                Toggle("Poster in kompakter Liste", isOn: $displaySettings.showPosterInCompactList)
            }

            Section {
                Button(role: .destructive) {
                    displaySettings.resetToDefaults()
                } label: {
                    Label("Auf Standard zurücksetzen", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Tipp: Wenn du hier wild rumspielst – keine Sorge. Reset bringt dich in 1 Tap wieder zurück in die Realität.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Darstellung")
        .navigationBarTitleDisplayMode(.inline)
        // Redundant zur Sicherheit: innerhalb des Settings-Flows soll die Darstellung sofort umschalten.
        .preferredColorScheme(displaySettings.preferredColorScheme)
        .tint(displaySettings.tintColor)
        .fontDesign(displaySettings.preferredFontDesign)
    }
}

// MARK: - Accent Picker (Grid)

private struct AccentColorGridPicker: View {

    @Binding var selection: DisplaySettings.AccentColorPreference

    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 10, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Akzentfarbe")
                Spacer()
                Text(selection.label)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(DisplaySettings.AccentColorPreference.allCases) { option in
                    Button {
                        selection = option
                    } label: {
                        ZStack {
                            Circle()
                                .fill(option.color)
                                .frame(width: 34, height: 34)

                            if selection == option {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.85), lineWidth: 2)

                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Color.white)
                                    .shadow(radius: 2)
                            }
                        }
                        .accessibilityLabel(option.label)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Typography Preview

private struct FontDesignPreviewCard: View {

    let design: Font.Design

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorschau")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("FilmFreaks – Watchlist")
                    .font(.headline)

                Text("Dune • 2021 · 155 min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("„Sieht sofort anders aus – ohne dass Accessibility leidet.“")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .fontDesign(design)
        .padding(.vertical, 4)
    }
}
