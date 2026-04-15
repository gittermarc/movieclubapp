//
//  ContentActivityPreviewSnapshotBuilder.swift
//  filmfreaks
//
//  Created on 08.04.26.
//

import Foundation

struct ContentActivityPreviewSnapshot {
    let items: [UnifiedGroupActivityEvent]
    let allItems: [UnifiedGroupActivityEvent]
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
        let allItems = merge(
            movieItems: input.movieEvents.map { UnifiedGroupActivityEvent(movieEvent: $0) },
            nightItems: input.movieNightEvents.map { UnifiedGroupActivityEvent(movieNightActivity: $0) }
        )

        let previewItems = merge(
            movieItems: input.movieEvents
                .prefix(input.perSourceLimit)
                .map { UnifiedGroupActivityEvent(movieEvent: $0) },
            nightItems: input.movieNightEvents
                .prefix(input.perSourceLimit)
                .map { UnifiedGroupActivityEvent(movieNightActivity: $0) }
        )

        return ContentActivityPreviewSnapshot(
            items: Array(previewItems.prefix(input.totalLimit)),
            allItems: allItems
        )
    }

    static func newEventsCount(
        in events: [UnifiedGroupActivityEvent],
        currentUserId: UUID?,
        currentUserName: String?,
        unseenThreshold: Date
    ) -> Int {
        events.filter {
            isEventNew(
                $0,
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                unseenThreshold: unseenThreshold
            )
        }.count
    }

    private static func merge(
        movieItems: [UnifiedGroupActivityEvent],
        nightItems: [UnifiedGroupActivityEvent]
    ) -> [UnifiedGroupActivityEvent] {
        Array((movieItems + nightItems).enumerated())
            .sorted { lhs, rhs in
                if lhs.element.date != rhs.element.date {
                    return lhs.element.date > rhs.element.date
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func isEventNew(
        _ event: UnifiedGroupActivityEvent,
        currentUserId: UUID?,
        currentUserName: String?,
        unseenThreshold: Date
    ) -> Bool {
        guard event.date > unseenThreshold else { return false }
        guard !isOwnEvent(event, currentUserId: currentUserId, currentUserName: currentUserName) else { return false }
        return true
    }

    private static func isOwnEvent(
        _ event: UnifiedGroupActivityEvent,
        currentUserId: UUID?,
        currentUserName: String?
    ) -> Bool {
        if let currentUserId, let actorUserId = event.actorUserId, actorUserId == currentUserId {
            return true
        }

        let normalizedCurrentUserName = normalizeName(currentUserName)
        let normalizedActorName = normalizeName(event.actorDisplayName)
        guard let normalizedCurrentUserName, let normalizedActorName else { return false }
        return normalizedCurrentUserName == normalizedActorName
    }

    private static func normalizeName(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
