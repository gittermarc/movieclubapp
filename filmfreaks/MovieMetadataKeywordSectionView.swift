//
//  MovieMetadataKeywordSectionView.swift
//  filmfreaks
//
//  Reusable keyword chip section for movie detail surfaces.
//

internal import SwiftUI

struct MovieMetadataKeywordSectionView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let title: String
    let keywordNames: [String]
    let collapsedLimit: Int

    @State private var isExpanded = false

    init(
        title: String = "Schlüsselwörter",
        keywordNames: [String],
        collapsedLimit: Int = 8
    ) {
        self.title = title
        self.keywordNames = keywordNames
        self.collapsedLimit = collapsedLimit
    }

    private var normalizedKeywordNames: [String] {
        MovieMetadataTagPresentation.normalizedNames(from: keywordNames)
    }

    private var visibleKeywordNames: [String] {
        guard normalizedKeywordNames.count > collapsedLimit, isExpanded == false else {
            return normalizedKeywordNames
        }

        return Array(normalizedKeywordNames.prefix(collapsedLimit))
    }

    private var hiddenKeywordCount: Int {
        max(0, normalizedKeywordNames.count - collapsedLimit)
    }

    var body: some View {
        if normalizedKeywordNames.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline).bold()

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .top)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(visibleKeywordNames, id: \.self) { keyword in
                        keywordChip(keyword)
                    }
                }

                if hiddenKeywordCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))

                            Text(isExpanded ? "Weniger anzeigen" : "Weitere \(hiddenKeywordCount) anzeigen")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(displaySettings.tintUltraSoftBackground)
                        .overlay(
                            Capsule()
                                .stroke(displaySettings.tintStroke.opacity(0.55), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func keywordChip(_ keyword: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(displaySettings.tintColor)

            Text(keyword)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(displaySettings.tintUltraSoftBackground)
        .overlay(
            Capsule()
                .stroke(displaySettings.tintStroke.opacity(0.55), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
