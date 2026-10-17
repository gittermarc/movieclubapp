//
//  StatsSnapshotBuilder+PickInsights.swift
//  filmfreaks
//
//  Recommendation insight computation for Stats.
//

import Foundation

nonisolated private enum StatsPickInsightsRules {
    static let minimumRatingsForSafePick = 4
    static let minimumAverageForSafePick = 7.0

    static let minimumRatingsForDaringPick = 4
    static let minimumAverageForDaringPick = 5.5
    static let minimumDeviationForDaringPick = 1.35

    static let minimumRatingsForCrowdPleaser = 5
    static let minimumAverageForCrowdPleaser = 7.0
    static let maximumDeviationForCrowdPleaser = 0.9
}

extension StatsSnapshotBuilder {

    nonisolated static func computePickInsights(
        movies: [Movie],
        displayedScore: (Rating) -> Double?
    ) -> StatsPickInsightsSnapshot {
        let aggregates = movies.compactMap { movie in
            pickAggregate(for: movie, displayedScore: displayedScore)
        }

        let safePick = bestSafePick(from: aggregates)
        let daringPick = bestDaringPick(from: aggregates)
        let crowdPleaser = bestCrowdPleaser(from: aggregates, excludingMovieIds: [safePick?.movie.id].compactMap { $0 })

        return StatsPickInsightsSnapshot(
            safePick: safePick,
            daringPick: daringPick,
            crowdPleaser: crowdPleaser
        )
    }

    nonisolated private static func pickAggregate(
        for movie: Movie,
        displayedScore: (Rating) -> Double?
    ) -> StatsPickInsight? {
        let values = movie.ratings.compactMap { displayedScore($0) }
        guard !values.isEmpty else { return nil }

        let averageRating = values.reduce(0, +) / Double(values.count)
        let deviation = standardDeviation(values)

        return StatsPickInsight(
            movie: movie,
            averageRating: averageRating,
            ratingsCount: values.count,
            standardDeviation: deviation,
            recommendationScore: 0
        )
    }

    nonisolated private static func bestSafePick(
        from aggregates: [StatsPickInsight]
    ) -> StatsPickInsight? {
        let candidates = aggregates.compactMap { aggregate -> StatsPickInsight? in
            guard aggregate.ratingsCount >= StatsPickInsightsRules.minimumRatingsForSafePick else { return nil }
            guard aggregate.averageRating >= StatsPickInsightsRules.minimumAverageForSafePick else { return nil }

            let recommendationScore = aggregate.averageRating
                - (aggregate.standardDeviation * 1.1)
                + (Double(min(aggregate.ratingsCount, 5)) * 0.05)

            return StatsPickInsight(
                movie: aggregate.movie,
                averageRating: aggregate.averageRating,
                ratingsCount: aggregate.ratingsCount,
                standardDeviation: aggregate.standardDeviation,
                recommendationScore: recommendationScore
            )
        }

        return candidates.max(by: isBetterSafePickCandidate)
    }

    nonisolated private static func bestDaringPick(
        from aggregates: [StatsPickInsight]
    ) -> StatsPickInsight? {
        let candidates = aggregates.compactMap { aggregate -> StatsPickInsight? in
            guard aggregate.ratingsCount >= StatsPickInsightsRules.minimumRatingsForDaringPick else { return nil }
            guard aggregate.averageRating >= StatsPickInsightsRules.minimumAverageForDaringPick else { return nil }
            guard aggregate.standardDeviation >= StatsPickInsightsRules.minimumDeviationForDaringPick else { return nil }

            let recommendationScore = (aggregate.standardDeviation * 1.7)
                + (max(0, aggregate.averageRating - 6.0) * 0.3)
                + (Double(min(aggregate.ratingsCount, 5)) * 0.08)

            return StatsPickInsight(
                movie: aggregate.movie,
                averageRating: aggregate.averageRating,
                ratingsCount: aggregate.ratingsCount,
                standardDeviation: aggregate.standardDeviation,
                recommendationScore: recommendationScore
            )
        }

        return candidates.max(by: isBetterDaringPickCandidate)
    }

    nonisolated private static func bestCrowdPleaser(
        from aggregates: [StatsPickInsight],
        excludingMovieIds: [UUID]
    ) -> StatsPickInsight? {
        let excludedIds = Set(excludingMovieIds)
        let candidates = aggregates.compactMap { aggregate -> StatsPickInsight? in
            guard !excludedIds.contains(aggregate.movie.id) else { return nil }
            guard aggregate.ratingsCount >= StatsPickInsightsRules.minimumRatingsForCrowdPleaser else { return nil }
            guard aggregate.averageRating >= StatsPickInsightsRules.minimumAverageForCrowdPleaser else { return nil }
            guard aggregate.standardDeviation <= StatsPickInsightsRules.maximumDeviationForCrowdPleaser else { return nil }

            let recommendationScore = (aggregate.averageRating * 0.8)
                - (aggregate.standardDeviation * 1.5)
                + (Double(min(aggregate.ratingsCount, 6)) * 0.45)

            return StatsPickInsight(
                movie: aggregate.movie,
                averageRating: aggregate.averageRating,
                ratingsCount: aggregate.ratingsCount,
                standardDeviation: aggregate.standardDeviation,
                recommendationScore: recommendationScore
            )
        }

        return candidates.max(by: isBetterCrowdPleaserCandidate)
    }

    nonisolated private static func isBetterSafePickCandidate(
        _ left: StatsPickInsight,
        _ right: StatsPickInsight
    ) -> Bool {
        if abs(left.recommendationScore - right.recommendationScore) > 0.0001 {
            return left.recommendationScore < right.recommendationScore
        }
        if abs(left.averageRating - right.averageRating) > 0.0001 {
            return left.averageRating < right.averageRating
        }
        if abs(left.standardDeviation - right.standardDeviation) > 0.0001 {
            return left.standardDeviation > right.standardDeviation
        }
        if left.ratingsCount != right.ratingsCount {
            return left.ratingsCount < right.ratingsCount
        }
        return left.movie.title.localizedCaseInsensitiveCompare(right.movie.title) == .orderedDescending
    }

    nonisolated private static func isBetterDaringPickCandidate(
        _ left: StatsPickInsight,
        _ right: StatsPickInsight
    ) -> Bool {
        if abs(left.recommendationScore - right.recommendationScore) > 0.0001 {
            return left.recommendationScore < right.recommendationScore
        }
        if abs(left.standardDeviation - right.standardDeviation) > 0.0001 {
            return left.standardDeviation < right.standardDeviation
        }
        if abs(left.averageRating - right.averageRating) > 0.0001 {
            return left.averageRating < right.averageRating
        }
        if left.ratingsCount != right.ratingsCount {
            return left.ratingsCount < right.ratingsCount
        }
        return left.movie.title.localizedCaseInsensitiveCompare(right.movie.title) == .orderedDescending
    }

    nonisolated private static func isBetterCrowdPleaserCandidate(
        _ left: StatsPickInsight,
        _ right: StatsPickInsight
    ) -> Bool {
        if abs(left.recommendationScore - right.recommendationScore) > 0.0001 {
            return left.recommendationScore < right.recommendationScore
        }
        if left.ratingsCount != right.ratingsCount {
            return left.ratingsCount < right.ratingsCount
        }
        if abs(left.standardDeviation - right.standardDeviation) > 0.0001 {
            return left.standardDeviation > right.standardDeviation
        }
        if abs(left.averageRating - right.averageRating) > 0.0001 {
            return left.averageRating < right.averageRating
        }
        return left.movie.title.localizedCaseInsensitiveCompare(right.movie.title) == .orderedDescending
    }

    nonisolated private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
