//
//  ContentActivityPreviewSnapshotBuilder.swift
//  filmfreaks
//
//  Created on 08.04.26.
//

import Foundation

struct ContentActivityPreviewSnapshot: Sendable {
    let items: [UnifiedGroupActivityEvent]
    let allItems: [UnifiedGroupActivityEvent]
}

enum ContentActivityPreviewSnapshotBuilder {

    struct Input: Sendable {
        let watchedMovies: [Movie]
        let backlogMovies: [Movie]
        let ratingDisplayMode: RatingDisplayMode
        let movieNightEvents: [MovieNightActivityEvent]
        let precomputedMovieEvents: [GroupActivityEvent]?
        let perSourceLimit: Int
        let totalLimit: Int

        init(
            watchedMovies: [Movie],
            backlogMovies: [Movie],
            movieNightEvents: [MovieNightActivityEvent],
            ratingDisplayMode: RatingDisplayMode,
            perSourceLimit: Int = 10,
            totalLimit: Int = 3
        ) {
            self.watchedMovies = watchedMovies
            self.backlogMovies = backlogMovies
            self.ratingDisplayMode = ratingDisplayMode
            self.movieNightEvents = movieNightEvents
            self.precomputedMovieEvents = nil
            self.perSourceLimit = perSourceLimit
            self.totalLimit = totalLimit
        }

        init(
            movieEvents: [GroupActivityEvent],
            movieNightEvents: [MovieNightActivityEvent],
            perSourceLimit: Int = 10,
            totalLimit: Int = 3
        ) {
            self.watchedMovies = []
            self.backlogMovies = []
            self.ratingDisplayMode = .ratingAverage
            self.movieNightEvents = movieNightEvents
            self.precomputedMovieEvents = movieEvents
            self.perSourceLimit = perSourceLimit
            self.totalLimit = totalLimit
        }
    }

    static func build(input: Input) -> ContentActivityPreviewSnapshot {
        let movieEvents = input.precomputedMovieEvents
            ?? buildMovieEvents(
                watchedMovies: input.watchedMovies,
                backlogMovies: input.backlogMovies,
                displayMode: input.ratingDisplayMode
            )
        let sortedNightEvents = input.movieNightEvents.sorted { $0.createdAt > $1.createdAt }

        let allItems = merge(
            movieItems: movieEvents.map { UnifiedGroupActivityEvent(movieEvent: $0) },
            nightItems: sortedNightEvents.map { UnifiedGroupActivityEvent(movieNightActivity: $0) }
        )

        let previewItems = merge(
            movieItems: movieEvents
                .prefix(input.perSourceLimit)
                .map { UnifiedGroupActivityEvent(movieEvent: $0) },
            nightItems: sortedNightEvents
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

    private static func buildMovieEvents(
        watchedMovies: [Movie],
        backlogMovies: [Movie],
        displayMode: RatingDisplayMode
    ) -> [GroupActivityEvent] {
        let allMovies = watchedMovies + backlogMovies
        guard !allMovies.isEmpty else { return [] }

        var events: [GroupActivityEvent] = []
        events.reserveCapacity(allMovies.count * 2)

        for movie in allMovies {
            if let addedAt = movie.addedAt {
                let actorName = activityPreviewFirstNonEmpty(movie.addedByName, movie.suggestedBy)
                events.append(
                    GroupActivityEvent(
                        kind: .movieAdded,
                        date: addedAt,
                        actorName: actorName,
                        actorId: movie.addedById,
                        movieId: movie.id,
                        movieTitle: movie.title,
                        movieYear: movie.year,
                        posterPath: movie.posterPath,
                        ratingValue: nil
                    )
                )
            }

            for rating in movie.ratings {
                guard let date = rating.updatedAt else { continue }
                let value = activityPreviewRatingValue(for: rating, displayMode: displayMode)

                events.append(
                    GroupActivityEvent(
                        kind: .movieRated,
                        date: date,
                        actorName: rating.reviewerName,
                        actorId: rating.reviewerId,
                        movieId: movie.id,
                        movieTitle: movie.title,
                        movieYear: movie.year,
                        posterPath: movie.posterPath,
                        ratingValue: value
                    )
                )
            }
        }

        events.sort { $0.date > $1.date }
        return events
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

private func activityPreviewFirstNonEmpty(_ a: String?, _ b: String?) -> String? {
    if let a, !a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return a }
    if let b, !b.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return b }
    return nil
}

private func activityPreviewRatingValue(for rating: Rating, displayMode: RatingDisplayMode) -> Double? {
    switch displayMode {
    case .ratingAverage:
        let value = rating.averageScoreNormalizedTo10
        return value <= 0 ? nil : value
    case .fazitAverage:
        if let fs = rating.fazitScore {
            return Double(fs)
        }
        let fallback = rating.averageScoreNormalizedTo10
        return fallback <= 0 ? nil : fallback
    }
}
