//
//  CornerStylePickerRow.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

struct CornerStylePickerRow: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Ecken & Rundungen", selection: $displaySettings.cornerStyle) {
                ForEach(DisplaySettings.CornerStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)
            showingHintText
        }
        .padding(.vertical, 2)
    }

    private var showingHintText: some View {
        Text("\(displaySettings.cornerStyle.shortHint) Betrifft Poster, Karten und Chips – rein optisch.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
