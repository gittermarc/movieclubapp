//
//  MovieNightDetailSheet+Header.swift
//  filmfreaks
//
//  P0.3: split out header + group-context banner.
//

import Foundation
internal import SwiftUI

extension MovieNightDetailSheet {

    func headerCard(event: MovieNightEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle(for: event))
                        .font(.title3.weight(.semibold))
                    Text("Vorgeschlagen von \(event.proposerName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    Image(systemName: statusSymbol(for: event))
                        .symbolRenderingMode(.hierarchical)
                    Text(statusText(for: event))
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .circular)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .circular)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .foregroundStyle(.secondary)
            }

            if let suggested = event.suggestedMovie {
                MovieNightSelectedMovieRowView(movie: suggested)
            }

            if let note = normalized(event.note) {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(displaySettings.metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    var contextNotReadyCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "icloud.and.arrow.down")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gruppe wird noch geladen …")
                    .font(.subheadline.weight(.semibold))
                Text("Aktionen sind kurz blockiert, damit nichts im falschen Cloud-Scope landet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Neu laden") {
                reloadGroupContextAndNightData()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(displaySettings.metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    func headerTitle(for event: MovieNightEvent) -> String {
        Self.headerFormatter.string(from: event.proposedStart)
    }

    func statusText(for event: MovieNightEvent) -> String {
        switch event.status {
        case .open: return "Vorschlag"
        case .scheduled: return "Geplant"
        case .cancelled: return "Abgesagt"
        }
    }

    func statusSymbol(for event: MovieNightEvent) -> String {
        switch event.status {
        case .open: return "sparkles"
        case .scheduled: return "checkmark.seal.fill"
        case .cancelled: return "xmark.seal.fill"
        }
    }

    func normalized(_ value: String?) -> String? {
        guard let raw = value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static let headerFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEEE, d. MMM · HH:mm")
        return df
    }()
}
