//
//  MovieSearchDiscoverySectionHeaderView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchDiscoverySectionHeaderView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let shelf: MovieDiscoveryShelf
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: shelf.kind.symbolName)
                        .foregroundStyle(.tint)
                    Text(shelf.title)
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Aktualisieren")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(displaySettings.tintSoftBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let subtitle = shelf.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
