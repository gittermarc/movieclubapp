//
//  MovieNightEventRow.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Single event row shown inside day list.
struct MovieNightEventRow: View {

    let event: MovieNightEvent
    let responses: [MovieNightResponse]

    @EnvironmentObject private var displaySettings: DisplaySettings

    private var timeLabel: String {
        Self.timeFormatter.string(from: event.proposedStart)
    }

    private var statusMeta: StatusMeta {
        switch event.status {
        case .open:
            return StatusMeta(title: "Vorschlag", symbol: "hand.raised.fill")
        case .scheduled:
            return StatusMeta(title: "Geplant", symbol: "checkmark.seal.fill")
        case .cancelled:
            return StatusMeta(title: "Abgesagt", symbol: "xmark.seal.fill")
        }
    }

    private var counts: ResponseCounts {
        let accepted = responses.filter { $0.decision == .accepted }.count
        let declined = responses.filter { $0.decision == .declined }.count
        let pending = responses.filter { $0.decision == .pending }.count
        return ResponseCounts(accepted: accepted, declined: declined, pending: pending)
    }

    private var hasNote: Bool {
        let note = event.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        return !(note?.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topLine
            metaLine
            responseLine
        }
        .contentShape(Rectangle())
    }

    private var topLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(timeLabel)
                .font(.headline)
                .monospacedDigit()

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                Image(systemName: statusMeta.symbol)
                    .symbolRenderingMode(.hierarchical)

                Text(statusMeta.title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
    }

    @ViewBuilder
    private var metaLine: some View {
        HStack(spacing: 8) {
            Label(event.proposerName, systemImage: "person.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if hasNote, let note = event.note?.trimmingCharacters(in: .whitespacesAndNewlines) {
                Text("•")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var responseLine: some View {
        if responses.isEmpty {
            Text("Noch keine Antworten")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        } else {
            HStack(spacing: 12) {
                responseChip(value: counts.accepted, symbol: "checkmark.circle.fill", label: "Zusagen")
                responseChip(value: counts.declined, symbol: "xmark.circle.fill", label: "Absagen")
                responseChip(value: counts.pending, symbol: "questionmark.circle.fill", label: "Offen")

                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            .foregroundStyle(.secondary)
        }
    }

    private func responseChip(value: Int, symbol: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
            Text("\(value)")
                .font(.caption.weight(.semibold))
        }
        .accessibilityLabel("\(label): \(value)")
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()
}

private struct StatusMeta {
    let title: String
    let symbol: String
}

private struct ResponseCounts {
    let accepted: Int
    let declined: Int
    let pending: Int
}
