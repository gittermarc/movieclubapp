//
//  GoalCardContainer.swift
//  filmfreaks
//

internal import SwiftUI

/// Simple card wrapper used by Goals screens.
/// Avoids duplicating background/rounding/shadow styling.
struct GoalCardContainer<Content: View>: View {

    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}
