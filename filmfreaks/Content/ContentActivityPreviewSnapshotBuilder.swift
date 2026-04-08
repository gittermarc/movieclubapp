//
//  ContentActivityPreviewSnapshotBuilder.swift
//  filmfreaks
//
//  Created on 08.04.26.
//

import Foundation

struct ContentActivityPreviewSnapshot {
    let items: [UnifiedGroupActivityEvent]
}

enum ContentActivityPreviewSnapshotBuilder {

    struct Input {
        let movieEvents: [GroupActivityEvent]
        let movieNightEvents: [MovieNightActivityEvent]
        let perSourceLimit: Int
        let totalLimit: Int

        init(
            movieEvents: [GroupActivityEvent],
            movieNightEvents: [MovieNightActivityEvent],
            perSourceLimit: Int = 10,
            totalLimit: Int = 3
        ) {
            self.movieEvents = movieEvents
            self.movieNightEvents = movieNightEvents
            self.perSourceLimit = perSourceLimit
            self.totalLimit = totalLimit
        }
    }

    static func build(input: Input) -> ContentActivityPreviewSnapshot {
        let limitedMovieItems = input.movieEvents
            .prefix(input.perSourceLimit)
            .map { UnifiedGroupActivityEvent(movieEvent: $0) }

        let limitedNightItems = input.movieNightEvents
            .prefix(input.perSourceLimit)
            .map { UnifiedGroupActivityEvent(movieNightActivity: $0) }

        let combined = Array((limitedMovieItems + limitedNightItems).enumerated())
            .sorted(by: areInDescendingActivityOrder)
            .map(\.element)

        return ContentActivityPreviewSnapshot(
            items: Array(combined.prefix(input.totalLimit))
        )
    }

    private static func areInDescendingActivityOrder(
        _ lhs: (offset: Int, element: UnifiedGroupActivityEvent),
        _ rhs: (offset: Int, element: UnifiedGroupActivityEvent)
    ) -> Bool {
        if lhs.element.date != rhs.element.date {
            return lhs.element.date > rhs.element.date
        }
        return lhs.offset < rhs.offset
    }
}
