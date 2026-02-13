//
//  MovieNightActivityRowView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Row for movie night activity events, used inside group activity.
struct MovieNightActivityRowView: View {

    let event: MovieNightActivityEvent

    @EnvironmentObject private var displaySettings: DisplaySettings

    private var normalizedNote: String? {
        guard let raw = event.note else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(displaySettings.tintColor)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.titleText)
                    .font(.subheadline.weight(.semibold))

                Text(event.subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let normalizedNote {
                    Text(normalizedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
