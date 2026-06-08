//
//  MovieFactsGridView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieFactsGridView: View {
    let presentation: MovieFactsPresentation

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 10, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(presentation.items) { item in
                MovieFactCellView(item: item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MovieFactCellView: View {
    @EnvironmentObject private var displaySettings: DisplaySettings

    let item: MovieFactItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(item.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(displaySettings.tintSoftBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
