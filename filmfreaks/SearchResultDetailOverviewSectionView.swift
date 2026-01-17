//
//  SearchResultDetailOverviewSectionView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

struct SearchResultDetailOverviewSectionView: View {

    let overviewText: String
    @Binding var isExpanded: Bool

    var body: some View {
        SearchResultDetailSectionCard(title: "Handlung") {
            VStack(alignment: .leading, spacing: 10) {
                Text(overviewText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
