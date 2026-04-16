//
//  MovieDetailSectionCard.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift to keep the main view small and readable.
//

internal import SwiftUI

/// Einheitliches Card-Layout fuer `MovieDetailView`.
struct MovieDetailSectionCard<Content: View>: View {
    private let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
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
