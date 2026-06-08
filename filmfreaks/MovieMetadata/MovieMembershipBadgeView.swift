//
//  MovieMembershipBadgeView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieMembershipBadgeView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let state: MovieMetadataMembershipState

    var body: some View {
        Label(state.title, systemImage: state.systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(backgroundStyle)
            .clipShape(Capsule())
    }

    private var foregroundStyle: AnyShapeStyle {
        switch state {
        case .current:
            return AnyShapeStyle(.white)
        case .watched:
            return AnyShapeStyle(.green)
        case .backlog:
            return AnyShapeStyle(.tint)
        case .missing:
            return AnyShapeStyle(.secondary)
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch state {
        case .current:
            return AnyShapeStyle(Color.accentColor.opacity(0.75))
        case .watched:
            return AnyShapeStyle(Color.green.opacity(0.14))
        case .backlog:
            return AnyShapeStyle(displaySettings.tintUltraSoftBackground)
        case .missing:
            return AnyShapeStyle(Color(.tertiarySystemBackground))
        }
    }
}
