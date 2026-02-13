//
//  ParticipantStatusPill.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

struct ParticipantStatusPill: View {

    enum Status {
        case pending
        case accepted
        case declined

        var title: String {
            switch self {
            case .pending: return "Offen"
            case .accepted: return "Dabei"
            case .declined: return "Nein"
            }
        }

        var systemImage: String {
            switch self {
            case .pending: return "hourglass"
            case .accepted: return "checkmark"
            case .declined: return "xmark"
            }
        }
    }

    let name: String
    let status: Status

    @EnvironmentObject private var displaySettings: DisplaySettings

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: status.systemImage)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(status.title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .circular)
                    .fill(background)
            )
        }
        .padding(.vertical, 2)
        .accessibilityLabel("\(name): \(status.title)")
    }

    private var background: Color {
        switch status {
        case .pending:
            return Color.primary.opacity(0.06)
        case .accepted:
            return displaySettings.tintColor.opacity(0.16)
        case .declined:
            return Color.red.opacity(0.12)
        }
    }
}
