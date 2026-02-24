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

    private var actorName: String {
        let trimmed = event.actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Jemand" : trimmed
    }

    private var verbText: String {
        switch event.kind {
        case .proposed:
            return "hat einen Filmabend vorgeschlagen"

        case .responded:
            switch event.decision {
            case .accepted:
                return "hat zugesagt"
            case .declined:
                return "hat abgesagt"
            case .pending, .none:
                return "hat geantwortet"
            }

        case .statusChanged:
            if event.newStatus == .scheduled {
                return "hat den Filmabend geplant"
            }
            if event.newStatus == .cancelled {
                return "hat den Filmabend abgesagt"
            }
            return "hat den Filmabend aktualisiert"

        case .deleted:
            return "hat den Vorschlag gelöscht"
        }
    }

    private var eventStartText: String {
        Self.eventStartFormatter.string(from: event.eventStart)
    }

    private var relativeTimeText: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: event.createdAt, relativeTo: Date())
    }

    private var headlineAttributedText: AttributedString {
        var result = AttributedString(actorName)
        result.font = .subheadline.weight(.semibold)

        var rest = AttributedString(" \(verbText) \(eventStartText)")
        rest.font = .subheadline

        result += rest
        return result
    }

    var body: some View {
        HStack(spacing: 12) {
            ActivityAvatarView(name: actorName, badgeSystemImage: event.systemImage)

            VStack(alignment: .leading, spacing: 4) {
                Text(headlineAttributedText)
                    .lineLimit(2)

                Text(relativeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let normalizedNote {
                    Text(normalizedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            calendarCard
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
    }

    private var calendarCard: some View {
        let day = Calendar.current.component(.day, from: event.eventStart)
        let month = Self.monthFormatter.string(from: event.eventStart).uppercased()

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.caption.weight(.semibold))
            Text(month)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(displaySettings.tintColor)
        .frame(width: 28, height: 42)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }

    private static let eventStartFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE, d. MMM · HH:mm")
        return df
    }()

    private static let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df
    }()
}
