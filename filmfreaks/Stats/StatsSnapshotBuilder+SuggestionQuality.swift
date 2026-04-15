//
//  StatsSnapshotBuilder+SuggestionQuality.swift
//  filmfreaks
//
//  Suggestion quality and profile insight computation for Stats.
//

import Foundation

nonisolated private enum StatsSuggestionQualityRules {
    static let minimumRatingsPerSuggestedMovie = 3
    static let minimumRatedSuggestionsPerPerson = 3
    static let minimumDatedSuggestionsPerPerson = 2

    static let minimumAverageForCrowdPleaser = 7.0
    static let maximumDeviationForCrowdPleaser = 1.1

    static let minimumDeviationForControversial = 2.1
    static let minimumAverageForControversial = 5.0
}

nonisolated private struct StatsSuggestedMovieAggregate {
    let suggesterKey: String
    let suggesterName: String
    let averageRating: Double
    let standardDeviation: Double
    let daysToWatch: Double?

    var isCrowdPleaser: Bool {
        averageRating >= StatsSuggestionQualityRules.minimumAverageForCrowdPleaser
            && standardDeviation <= StatsSuggestionQualityRules.maximumDeviationForCrowdPleaser
    }

    var isControversial: Bool {
        standardDeviation >= StatsSuggestionQualityRules.minimumDeviationForControversial
            && averageRating >= StatsSuggestionQualityRules.minimumAverageForControversial
    }
}

nonisolated private struct StatsSuggestionPersonAggregate {
    let suggesterName: String
    var ratedSuggestionsCount: Int
    var totalAverageRating: Double
    var crowdPleaserCount: Int
    var controversialCount: Int
    var datedSuggestionsCount: Int
    var totalDaysToWatch: Double
}

extension StatsSnapshotBuilder {

    nonisolated static func computeSuggestionQuality(
        movies: [Movie],
        ratingDisplayMode: RatingDisplayMode,
        displayedScore: (Rating) -> Double?
    ) -> StatsSuggestionQualitySnapshot {
        let aggregates = suggestedMovieAggregates(
            movies: movies,
            ratingDisplayMode: ratingDisplayMode,
            displayedScore: displayedScore
        )

        guard !aggregates.isEmpty else {
            return .empty
        }

        let personAggregates = suggestionPersonAggregates(from: aggregates)

        return StatsSuggestionQualitySnapshot(
            bestAverageRatingSuggester: bestAverageRatingSuggester(from: personAggregates),
            bestHitRateSuggester: bestHitRateSuggester(from: personAggregates),
            mostControversialSuggester: mostControversialSuggester(from: personAggregates),
            fastestToWatchSuggester: fastestToWatchSuggester(from: personAggregates, ratingDisplayMode: ratingDisplayMode)
        )
    }

    nonisolated private static func suggestedMovieAggregates(
        movies: [Movie],
        ratingDisplayMode: RatingDisplayMode,
        displayedScore: (Rating) -> Double?
    ) -> [StatsSuggestedMovieAggregate] {
        movies.compactMap { movie in
            let suggester = normalizedSuggesterName(from: movie.suggestedBy)
            guard let suggester else { return nil }

            let values = movie.ratings.compactMap { displayedScore($0) }
            guard values.count >= StatsSuggestionQualityRules.minimumRatingsPerSuggestedMovie else {
                return nil
            }

            guard let averageRating = movie.groupAverage(for: ratingDisplayMode) else {
                return nil
            }

            return StatsSuggestedMovieAggregate(
                suggesterKey: suggester.key,
                suggesterName: suggester.displayName,
                averageRating: averageRating,
                standardDeviation: standardDeviation(values),
                daysToWatch: daysToWatch(for: movie)
            )
        }
    }

    nonisolated private static func suggestionPersonAggregates(
        from movieAggregates: [StatsSuggestedMovieAggregate]
    ) -> [String: StatsSuggestionPersonAggregate] {
        var result: [String: StatsSuggestionPersonAggregate] = [:]

        for aggregate in movieAggregates {
            var entry = result[aggregate.suggesterKey] ?? StatsSuggestionPersonAggregate(
                suggesterName: aggregate.suggesterName,
                ratedSuggestionsCount: 0,
                totalAverageRating: 0,
                crowdPleaserCount: 0,
                controversialCount: 0,
                datedSuggestionsCount: 0,
                totalDaysToWatch: 0
            )

            entry.ratedSuggestionsCount += 1
            entry.totalAverageRating += aggregate.averageRating

            if aggregate.isCrowdPleaser {
                entry.crowdPleaserCount += 1
            }

            if aggregate.isControversial {
                entry.controversialCount += 1
            }

            if let daysToWatch = aggregate.daysToWatch {
                entry.datedSuggestionsCount += 1
                entry.totalDaysToWatch += daysToWatch
            }

            result[aggregate.suggesterKey] = entry
        }

        return result
    }

    nonisolated private static func bestAverageRatingSuggester(
        from personAggregates: [String: StatsSuggestionPersonAggregate]
    ) -> StatsSuggestionQualityInsight? {
        let candidates = personAggregates.values.compactMap { aggregate -> StatsSuggestionQualityInsight? in
            guard aggregate.ratedSuggestionsCount >= StatsSuggestionQualityRules.minimumRatedSuggestionsPerPerson else {
                return nil
            }

            return makeSuggestionQualityInsight(from: aggregate)
        }

        return candidates.max(by: { left, right in
            if abs(left.averageGroupRating - right.averageGroupRating) > 0.0001 {
                return left.averageGroupRating < right.averageGroupRating
            }
            if left.ratedSuggestionsCount != right.ratedSuggestionsCount {
                return left.ratedSuggestionsCount < right.ratedSuggestionsCount
            }
            return left.suggesterName.localizedCaseInsensitiveCompare(right.suggesterName) == .orderedDescending
        })
    }

    nonisolated private static func bestHitRateSuggester(
        from personAggregates: [String: StatsSuggestionPersonAggregate]
    ) -> StatsSuggestionQualityInsight? {
        let candidates = personAggregates.values.compactMap { aggregate -> StatsSuggestionQualityInsight? in
            guard aggregate.ratedSuggestionsCount >= StatsSuggestionQualityRules.minimumRatedSuggestionsPerPerson else {
                return nil
            }
            guard aggregate.crowdPleaserCount > 0 else { return nil }

            return makeSuggestionQualityInsight(from: aggregate)
        }

        return candidates.max(by: { left, right in
            if abs(left.crowdPleaserRate - right.crowdPleaserRate) > 0.0001 {
                return left.crowdPleaserRate < right.crowdPleaserRate
            }
            if left.crowdPleaserCount != right.crowdPleaserCount {
                return left.crowdPleaserCount < right.crowdPleaserCount
            }
            if abs(left.averageGroupRating - right.averageGroupRating) > 0.0001 {
                return left.averageGroupRating < right.averageGroupRating
            }
            return left.suggesterName.localizedCaseInsensitiveCompare(right.suggesterName) == .orderedDescending
        })
    }

    nonisolated private static func mostControversialSuggester(
        from personAggregates: [String: StatsSuggestionPersonAggregate]
    ) -> StatsSuggestionQualityInsight? {
        let candidates = personAggregates.values.compactMap { aggregate -> StatsSuggestionQualityInsight? in
            guard aggregate.ratedSuggestionsCount >= StatsSuggestionQualityRules.minimumRatedSuggestionsPerPerson else {
                return nil
            }
            guard aggregate.controversialCount > 0 else { return nil }

            return makeSuggestionQualityInsight(from: aggregate)
        }

        return candidates.max(by: { left, right in
            if abs(left.controversialRate - right.controversialRate) > 0.0001 {
                return left.controversialRate < right.controversialRate
            }
            if left.controversialCount != right.controversialCount {
                return left.controversialCount < right.controversialCount
            }
            if abs(left.averageGroupRating - right.averageGroupRating) > 0.0001 {
                return left.averageGroupRating < right.averageGroupRating
            }
            return left.suggesterName.localizedCaseInsensitiveCompare(right.suggesterName) == .orderedDescending
        })
    }

    nonisolated private static func fastestToWatchSuggester(
        from personAggregates: [String: StatsSuggestionPersonAggregate],
        ratingDisplayMode: RatingDisplayMode
    ) -> StatsSuggestionWatchTimingInsight? {
        let candidates = personAggregates.values.compactMap { aggregate -> StatsSuggestionWatchTimingInsight? in
            guard aggregate.ratedSuggestionsCount >= StatsSuggestionQualityRules.minimumRatedSuggestionsPerPerson else {
                return nil
            }
            guard aggregate.datedSuggestionsCount >= StatsSuggestionQualityRules.minimumDatedSuggestionsPerPerson else {
                return nil
            }

            let averageDaysToWatch = aggregate.totalDaysToWatch / Double(aggregate.datedSuggestionsCount)
            let summary = makeSuggestionQualityInsight(from: aggregate)

            return StatsSuggestionWatchTimingInsight(
                suggesterName: aggregate.suggesterName,
                datedSuggestionsCount: aggregate.datedSuggestionsCount,
                averageDaysToWatch: averageDaysToWatch,
                averageGroupRating: summary.averageGroupRating,
                ratedSuggestionsCount: summary.ratedSuggestionsCount,
                ratingDisplayMode: ratingDisplayMode
            )
        }

        return candidates.min(by: { left, right in
            if abs(left.averageDaysToWatch - right.averageDaysToWatch) > 0.0001 {
                return left.averageDaysToWatch < right.averageDaysToWatch
            }
            if left.datedSuggestionsCount != right.datedSuggestionsCount {
                return left.datedSuggestionsCount > right.datedSuggestionsCount
            }
            if abs(left.averageGroupRating - right.averageGroupRating) > 0.0001 {
                return left.averageGroupRating > right.averageGroupRating
            }
            return left.suggesterName.localizedCaseInsensitiveCompare(right.suggesterName) == .orderedAscending
        })
    }

    nonisolated private static func makeSuggestionQualityInsight(
        from aggregate: StatsSuggestionPersonAggregate
    ) -> StatsSuggestionQualityInsight {
        let averageGroupRating = aggregate.totalAverageRating / Double(aggregate.ratedSuggestionsCount)
        let crowdPleaserRate = Double(aggregate.crowdPleaserCount) / Double(aggregate.ratedSuggestionsCount)
        let controversialRate = Double(aggregate.controversialCount) / Double(aggregate.ratedSuggestionsCount)

        return StatsSuggestionQualityInsight(
            suggesterName: aggregate.suggesterName,
            ratedSuggestionsCount: aggregate.ratedSuggestionsCount,
            averageGroupRating: averageGroupRating,
            crowdPleaserCount: aggregate.crowdPleaserCount,
            crowdPleaserRate: crowdPleaserRate,
            controversialCount: aggregate.controversialCount,
            controversialRate: controversialRate
        )
    }

    nonisolated private static func normalizedSuggesterName(
        from rawSuggestedBy: String?
    ) -> (key: String, displayName: String)? {
        let trimmed = rawSuggestedBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return (key: trimmed.lowercased(), displayName: trimmed)
    }

    nonisolated private static func daysToWatch(for movie: Movie) -> Double? {
        guard let addedAt = movie.addedAt, let watchedDate = movie.watchedDate else {
            return nil
        }

        let delta = watchedDate.timeIntervalSince(addedAt)
        guard delta >= 0 else { return nil }

        return delta / 86_400.0
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
