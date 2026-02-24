//
//  ContentActivityPreviewModel.swift
//  filmfreaks
//
//  Created by Marc Fechner on 24.02.26.
//

internal import SwiftUI
import Combine

/// Computes the group activity preview items outside of the SwiftUI render path.
///
/// `ContentView.body` re-renders for many reasons (search text, filters, view style, etc.).
/// Building activity items is comparatively expensive (iterate movies + ratings + sort).
/// This model caches the result and only recomputes when the relevant inputs change.
@MainActor
final class ContentActivityPreviewModel: ObservableObject {

    @Published private(set) var items: [UnifiedGroupActivityEvent] = []

    func update(
        movieStore: MovieStore,
        movieNightStore: MovieNightStore,
        currentGroupId: String,
        ratingDisplayMode: RatingDisplayMode
    ) {
        let movieItems = movieStore
            .activityEvents(displayMode: ratingDisplayMode, limit: 10)
            .map { UnifiedGroupActivityEvent(movieEvent: $0) }

        let nightItems: [UnifiedGroupActivityEvent]
        if currentGroupId.isEmpty {
            nightItems = []
        } else {
            nightItems = movieNightStore
                .activityEvents(for: currentGroupId)
                .prefix(10)
                .map { UnifiedGroupActivityEvent(movieNightActivity: $0) }
        }

        let combined = (movieItems + nightItems)
            .sorted(by: { $0.date > $1.date })

        self.items = Array(combined.prefix(3))
    }
}
