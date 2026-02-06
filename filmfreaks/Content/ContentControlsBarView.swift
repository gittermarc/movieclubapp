//
//  ContentControlsBarView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Kompakte Sortier-/Filter-/Ansicht-Leiste.
///
/// Ziel: ContentView entlasten, ohne Logik zu verstecken.
struct ContentControlsBarView: View {

    let metrics: DisplaySettings.LayoutMetrics

    @Binding var selectedSort: MovieSortOption
    @Binding var filterByUser: User?
    let users: [User]

    let filterLabelText: String
    let filterHintText: String?

    @Binding var viewStyleRaw: String
    let selectedViewStyle: MovieViewStyle

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(MovieSortOption.allCases) { option in
                        Button(option.rawValue) {
                            selectedSort = option
                        }
                    }
                } label: {
                    ContentControlChip(metrics: metrics, icon: "arrow.up.arrow.down", title: selectedSort.rawValue)
                }

                Menu {
                    Button("Alle") {
                        filterByUser = nil
                    }

                    if users.isEmpty {
                        Text("Keine Mitglieder")
                    } else {
                        ForEach(users) { user in
                            Button(user.name) {
                                filterByUser = user
                            }
                        }
                    }
                } label: {
                    ContentControlChip(
                        metrics: metrics,
                        icon: "line.3.horizontal.decrease.circle",
                        title: filterLabelText
                    )
                }

                Menu {
                    ForEach(MovieViewStyle.allCases) { style in
                        Button {
                            viewStyleRaw = style.rawValue
                        } label: {
                            Label(style.rawValue, systemImage: style.icon)
                        }
                    }
                } label: {
                    ContentControlChip(metrics: metrics, icon: selectedViewStyle.icon, title: selectedViewStyle.rawValue)
                }

                if filterByUser != nil {
                    Button {
                        filterByUser = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Filter zurücksetzen")
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            if let hint = filterHintText {
                Divider()
                    .opacity(0.7)

                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(metrics.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ContentControlChip: View {

    let metrics: DisplaySettings.LayoutMetrics
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: metrics.chipContentSpacing) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, metrics.chipHorizontalPadding)
        .padding(.vertical, metrics.chipVerticalPadding)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
