//
//  SearchResultDetailAddToListSectionView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

struct SearchResultDetailAddToListSectionView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    @Binding var isInWatched: Bool
    @Binding var isInBacklog: Bool
    let makeMovie: () -> Movie
    let onAddToWatched: (Movie) -> Void
    let onAddToBacklog: (Movie) -> Void
    let onDone: () -> Void

    var body: some View {
        SearchResultDetailSectionCard(title: "Zu deiner Liste hinzufügen") {
            if isInWatched || isInBacklog {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    statusText
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    let movie = makeMovie()
                    onAddToWatched(movie)
                    isInWatched = true
                    onDone()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(isInWatched ? "Schon in Gesehen" : "Zu gesehen hinzufügen")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        isInWatched
                        ? Color.green.opacity(0.10)
                        : Color.green.opacity(0.18)
                    )
                    .foregroundStyle(isInWatched ? Color.secondary : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isInWatched)

                Button {
                    let movie = makeMovie()
                    onAddToBacklog(movie)
                    isInBacklog = true
                    onDone()
                } label: {
                    HStack {
                        Image(systemName: "text.badge.plus")
                        Text(isInBacklog ? "Schon im Backlog" : "In Backlog speichern")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        isInBacklog
                        ? displaySettings.tintUltraSoftBackground
                        : displaySettings.tint(0.15)
                    )
                    // Avoid ternary type mismatch: .secondary is HierarchicalShapeStyle,
                    // .tint is TintShapeStyle. Wrap both in AnyShapeStyle.
                    .foregroundStyle(isInBacklog ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isInBacklog)
            }
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if isInWatched && isInBacklog {
            Text("Dieser Film ist bereits in „Gesehen“ und im Backlog.")
        } else if isInWatched {
            Text("Dieser Film ist bereits in deiner „Gesehen“-Liste.")
        } else if isInBacklog {
            Text("Dieser Film ist bereits in deinem Backlog.")
        }
    }
}
