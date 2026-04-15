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
    @Published private(set) var allItems: [UnifiedGroupActivityEvent] = []

    func update(
        movieStore: MovieStore,
        movieNightStore: MovieNightStore,
        currentGroupId: String,
        ratingDisplayMode: RatingDisplayMode
    ) {
        let snapshot = ContentActivityPreviewSnapshotBuilder.build(
            input: .init(
                movieEvents: movieStore.activityEvents(displayMode: ratingDisplayMode),
                movieNightEvents: currentGroupId.isEmpty
                    ? []
                    : movieNightStore.activityEvents(for: currentGroupId)
            )
        )

        self.items = snapshot.items
        self.allItems = snapshot.allItems
    }
}
