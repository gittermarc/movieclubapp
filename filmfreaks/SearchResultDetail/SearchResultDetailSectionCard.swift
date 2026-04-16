//
//  SearchResultDetailSectionCard.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

/// Card-Wrapper im Stil der Detail-Views.
/// Eigene Version, damit SearchResultDetailView unabhängig von anderen Refactors bleibt.
struct SearchResultDetailSectionCard<Content: View>: View {

    private let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}
