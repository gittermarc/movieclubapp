//
//  timelineemptystate.swift
//  filmfreaks
//

internal import SwiftUI

struct TimelineEmptyStateView: View {

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Keine Filme in der Timeline")
                .font(.headline)

            Text("Für diese Auswahl gibt’s keine Filme mit Datum.\nGib in einem Film ein „Gemeinsam geschaut am“-Datum an – dann taucht er hier auf.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
