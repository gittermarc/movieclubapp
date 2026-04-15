//
//  StatsSnapshotBuilder+TasteDynamics.swift
//  filmfreaks
//
//  Social taste and group-dynamics insight computation for Stats.
//

import Foundation

private enum StatsTasteDynamicsRules {
    static let minimumSharedMoviesForPair = 3
    static let maximumAverageDifferenceForTwins = 1.4
    static let minimumAverageDifferenceForFriction = 1.8

    static let minimumComparableRatingsPerReviewer = 4
    static let minimumMeaningfulReviewerBias = 0.4

    static let hotTakeDeviationThreshold = 2.0
    static let minimumHotTakeCount = 2
}

private struct StatsPairKey: Hashable {
    let first: String
    let second: String

    init(_ a: String, _ b: String) {
        if a <= b {
            first = a
            second = b
        } else {
            first = b
            second = a
        }
    }
}

private struct StatsPairAggregate {
    let firstName: String
    let secondName: String
    var sharedMoviesCount: Int
    var totalAbsoluteDifference: Double
}

private struct StatsReviewerAggregate {
    let reviewerName: String
    var comparableRatingsCount: Int
    var totalBias: Double
    var totalAbsoluteDeviation: Double
    var hotTakeCount: Int
}

extension StatsSnapshotBuilder {

    nonisolated static func computeTasteDynamics(
        movies: [Movie],
        users: [User],
        displayedScore: (Rating) -> Double?,
        reviewerKey: (Rating) -> String
    ) -> StatsTasteDynamicsSnapshot {
        let knownReviewerNames = knownReviewerNamesByKey(users: users)

        var pairAggregates: [StatsPairKey: StatsPairAggregate] = [:]
        var reviewerAggregates: [String: StatsReviewerAggregate] = [:]

        for movie in movies {
            let scoresByReviewer = movieScoresByReviewer(
                movie: movie,
                knownReviewerNames: knownReviewerNames,
                displayedScore: displayedScore,
                reviewerKey: reviewerKey
            )

            guard scoresByReviewer.count >= 2 else { continue }

            accumulatePairDynamics(
                scoresByReviewer: scoresByReviewer,
                into: &pairAggregates
            )

            accumulateReviewerDynamics(
                scoresByReviewer: scoresByReviewer,
                into: &reviewerAggregates
            )
        }

        let tasteTwins = bestTasteTwins(from: pairAggregates)
        let frictionPair = biggestFrictionPair(from: pairAggregates)
        let strictestReviewer = strictestReviewer(from: reviewerAggregates)
        let mostGenerousReviewer = mostGenerousReviewer(from: reviewerAggregates)
        let hotTakeReviewer = hotTakeReviewer(from: reviewerAggregates)

        return StatsTasteDynamicsSnapshot(
            tasteTwins: tasteTwins,
            frictionPair: frictionPair,
            strictestReviewer: strictestReviewer,
            mostGenerousReviewer: mostGenerousReviewer,
            hotTakeReviewer: hotTakeReviewer
        )
    }

    nonisolated private static func knownReviewerNamesByKey(users: [User]) -> [String: String] {
        var result: [String: String] = [:]

        for user in users {
            let trimmedName = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }

            let idKey = "id:\(user.id.uuidString.lowercased())"
            let nameKey = "name:\(trimmedName.lowercased())"
            result[idKey] = trimmedName
            result[nameKey] = trimmedName
        }

        return result
    }

    nonisolated private static func movieScoresByReviewer(
        movie: Movie,
        knownReviewerNames: [String: String],
        displayedScore: (Rating) -> Double?,
        reviewerKey: (Rating) -> String
    ) -> [String: (name: String, score: Double)] {
        var scoresByReviewer: [String: (name: String, score: Double, updatedAt: Date?)] = [:]

        for rating in movie.ratings {
            guard let score = displayedScore(rating) else { continue }

            let key = reviewerKey(rating)
            let name = resolveReviewerName(
                key: key,
                rawReviewerName: rating.reviewerName,
                knownReviewerNames: knownReviewerNames
            )

            if let existing = scoresByReviewer[key] {
                if shouldReplaceRating(existingUpdatedAt: existing.updatedAt, candidateUpdatedAt: rating.updatedAt) {
                    scoresByReviewer[key] = (name: name, score: score, updatedAt: rating.updatedAt)
                }
            } else {
                scoresByReviewer[key] = (name: name, score: score, updatedAt: rating.updatedAt)
            }
        }

        return scoresByReviewer.mapValues { value in
            (name: value.name, score: value.score)
        }
    }

    nonisolated private static func resolveReviewerName(
        key: String,
        rawReviewerName: String,
        knownReviewerNames: [String: String]
    ) -> String {
        if let known = knownReviewerNames[key] {
            return known
        }

        let trimmedRaw = rawReviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRaw.isEmpty {
            return trimmedRaw
        }

        if key.hasPrefix("name:") {
            let fallback = String(key.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallback.isEmpty {
                return fallback
            }
        }

        return "Unbekannt"
    }

    nonisolated private static func shouldReplaceRating(
        existingUpdatedAt: Date?,
        candidateUpdatedAt: Date?
    ) -> Bool {
        switch (existingUpdatedAt, candidateUpdatedAt) {
        case let (.some(existing), .some(candidate)):
            return candidate >= existing
        case (.none, .some):
            return true
        case (.some, .none):
            return false
        case (.none, .none):
            return true
        }
    }

    nonisolated private static func accumulatePairDynamics(
        scoresByReviewer: [String: (name: String, score: Double)],
        into pairAggregates: inout [StatsPairKey: StatsPairAggregate]
    ) {
        let reviewers = scoresByReviewer
            .map { (key: $0.key, name: $0.value.name, score: $0.value.score) }
            .sorted {
                if $0.name.localizedCaseInsensitiveCompare($1.name) != .orderedSame {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.key < $1.key
            }

        guard reviewers.count >= 2 else { return }

        for leftIndex in 0..<(reviewers.count - 1) {
            for rightIndex in (leftIndex + 1)..<reviewers.count {
                let left = reviewers[leftIndex]
                let right = reviewers[rightIndex]
                let pairKey = StatsPairKey(left.key, right.key)
                let difference = abs(left.score - right.score)

                if var existing = pairAggregates[pairKey] {
                    existing.sharedMoviesCount += 1
                    existing.totalAbsoluteDifference += difference
                    pairAggregates[pairKey] = existing
                } else {
                    pairAggregates[pairKey] = StatsPairAggregate(
                        firstName: left.name,
                        secondName: right.name,
                        sharedMoviesCount: 1,
                        totalAbsoluteDifference: difference
                    )
                }
            }
        }
    }

    nonisolated private static func accumulateReviewerDynamics(
        scoresByReviewer: [String: (name: String, score: Double)],
        into reviewerAggregates: inout [String: StatsReviewerAggregate]
    ) {
        let allEntries = Array(scoresByReviewer)
        guard allEntries.count >= 2 else { return }

        for entry in allEntries {
            let others = allEntries.filter { $0.key != entry.key }
            guard !others.isEmpty else { continue }

            let othersAverage = others
                .map { $0.value.score }
                .reduce(0, +) / Double(others.count)

            let bias = entry.value.score - othersAverage
            let absoluteDeviation = abs(bias)

            if var existing = reviewerAggregates[entry.key] {
                existing.comparableRatingsCount += 1
                existing.totalBias += bias
                existing.totalAbsoluteDeviation += absoluteDeviation
                if absoluteDeviation >= StatsTasteDynamicsRules.hotTakeDeviationThreshold {
                    existing.hotTakeCount += 1
                }
                reviewerAggregates[entry.key] = existing
            } else {
                reviewerAggregates[entry.key] = StatsReviewerAggregate(
                    reviewerName: entry.value.name,
                    comparableRatingsCount: 1,
                    totalBias: bias,
                    totalAbsoluteDeviation: absoluteDeviation,
                    hotTakeCount: absoluteDeviation >= StatsTasteDynamicsRules.hotTakeDeviationThreshold ? 1 : 0
                )
            }
        }
    }

    nonisolated private static func bestTasteTwins(
        from pairAggregates: [StatsPairKey: StatsPairAggregate]
    ) -> StatsTastePairInsight? {
        let candidates = pairAggregates.values.compactMap { aggregate -> StatsTastePairInsight? in
            guard aggregate.sharedMoviesCount >= StatsTasteDynamicsRules.minimumSharedMoviesForPair else { return nil }

            let averageDifference = aggregate.totalAbsoluteDifference / Double(aggregate.sharedMoviesCount)
            guard averageDifference <= StatsTasteDynamicsRules.maximumAverageDifferenceForTwins else { return nil }

            return StatsTastePairInsight(
                firstReviewerName: aggregate.firstName,
                secondReviewerName: aggregate.secondName,
                sharedMoviesCount: aggregate.sharedMoviesCount,
                averageDifference: averageDifference
            )
        }

        return candidates.min { left, right in
            if abs(left.averageDifference - right.averageDifference) > 0.0001 {
                return left.averageDifference < right.averageDifference
            }
            if left.sharedMoviesCount != right.sharedMoviesCount {
                return left.sharedMoviesCount > right.sharedMoviesCount
            }
            if left.firstReviewerName.localizedCaseInsensitiveCompare(right.firstReviewerName) != .orderedSame {
                return left.firstReviewerName.localizedCaseInsensitiveCompare(right.firstReviewerName) == .orderedAscending
            }
            return left.secondReviewerName.localizedCaseInsensitiveCompare(right.secondReviewerName) == .orderedAscending
        }
    }

    nonisolated private static func biggestFrictionPair(
        from pairAggregates: [StatsPairKey: StatsPairAggregate]
    ) -> StatsTastePairInsight? {
        let candidates = pairAggregates.values.compactMap { aggregate -> StatsTastePairInsight? in
            guard aggregate.sharedMoviesCount >= StatsTasteDynamicsRules.minimumSharedMoviesForPair else { return nil }

            let averageDifference = aggregate.totalAbsoluteDifference / Double(aggregate.sharedMoviesCount)
            guard averageDifference >= StatsTasteDynamicsRules.minimumAverageDifferenceForFriction else { return nil }

            return StatsTastePairInsight(
                firstReviewerName: aggregate.firstName,
                secondReviewerName: aggregate.secondName,
                sharedMoviesCount: aggregate.sharedMoviesCount,
                averageDifference: averageDifference
            )
        }

        return candidates.max { left, right in
            if abs(left.averageDifference - right.averageDifference) > 0.0001 {
                return left.averageDifference < right.averageDifference
            }
            if left.sharedMoviesCount != right.sharedMoviesCount {
                return left.sharedMoviesCount < right.sharedMoviesCount
            }
            if left.firstReviewerName.localizedCaseInsensitiveCompare(right.firstReviewerName) != .orderedSame {
                return left.firstReviewerName.localizedCaseInsensitiveCompare(right.firstReviewerName) == .orderedDescending
            }
            return left.secondReviewerName.localizedCaseInsensitiveCompare(right.secondReviewerName) == .orderedDescending
        }
    }

    nonisolated private static func strictestReviewer(
        from reviewerAggregates: [String: StatsReviewerAggregate]
    ) -> StatsReviewerBiasInsight? {
        let candidates = reviewerAggregates.values.compactMap { aggregate -> StatsReviewerBiasInsight? in
            guard aggregate.comparableRatingsCount >= StatsTasteDynamicsRules.minimumComparableRatingsPerReviewer else { return nil }

            let averageBias = aggregate.totalBias / Double(aggregate.comparableRatingsCount)
            guard averageBias <= -StatsTasteDynamicsRules.minimumMeaningfulReviewerBias else { return nil }

            return StatsReviewerBiasInsight(
                reviewerName: aggregate.reviewerName,
                comparableRatingsCount: aggregate.comparableRatingsCount,
                averageBias: averageBias
            )
        }

        return candidates.min { left, right in
            if abs(left.averageBias - right.averageBias) > 0.0001 {
                return left.averageBias < right.averageBias
            }
            if left.comparableRatingsCount != right.comparableRatingsCount {
                return left.comparableRatingsCount > right.comparableRatingsCount
            }
            return left.reviewerName.localizedCaseInsensitiveCompare(right.reviewerName) == .orderedAscending
        }
    }

    nonisolated private static func mostGenerousReviewer(
        from reviewerAggregates: [String: StatsReviewerAggregate]
    ) -> StatsReviewerBiasInsight? {
        let candidates = reviewerAggregates.values.compactMap { aggregate -> StatsReviewerBiasInsight? in
            guard aggregate.comparableRatingsCount >= StatsTasteDynamicsRules.minimumComparableRatingsPerReviewer else { return nil }

            let averageBias = aggregate.totalBias / Double(aggregate.comparableRatingsCount)
            guard averageBias >= StatsTasteDynamicsRules.minimumMeaningfulReviewerBias else { return nil }

            return StatsReviewerBiasInsight(
                reviewerName: aggregate.reviewerName,
                comparableRatingsCount: aggregate.comparableRatingsCount,
                averageBias: averageBias
            )
        }

        return candidates.max { left, right in
            if abs(left.averageBias - right.averageBias) > 0.0001 {
                return left.averageBias < right.averageBias
            }
            if left.comparableRatingsCount != right.comparableRatingsCount {
                return left.comparableRatingsCount < right.comparableRatingsCount
            }
            return left.reviewerName.localizedCaseInsensitiveCompare(right.reviewerName) == .orderedDescending
        }
    }

    nonisolated private static func hotTakeReviewer(
        from reviewerAggregates: [String: StatsReviewerAggregate]
    ) -> StatsHotTakeInsight? {
        let candidates = reviewerAggregates.values.compactMap { aggregate -> StatsHotTakeInsight? in
            guard aggregate.comparableRatingsCount >= StatsTasteDynamicsRules.minimumComparableRatingsPerReviewer else { return nil }
            guard aggregate.hotTakeCount >= StatsTasteDynamicsRules.minimumHotTakeCount else { return nil }

            let hotTakeRate = Double(aggregate.hotTakeCount) / Double(aggregate.comparableRatingsCount)
            let averageAbsoluteDeviation = aggregate.totalAbsoluteDeviation / Double(aggregate.comparableRatingsCount)

            return StatsHotTakeInsight(
                reviewerName: aggregate.reviewerName,
                hotTakeCount: aggregate.hotTakeCount,
                comparableRatingsCount: aggregate.comparableRatingsCount,
                hotTakeRate: hotTakeRate,
                averageAbsoluteDeviation: averageAbsoluteDeviation
            )
        }

        return candidates.max { left, right in
            if abs(left.hotTakeRate - right.hotTakeRate) > 0.0001 {
                return left.hotTakeRate < right.hotTakeRate
            }
            if left.hotTakeCount != right.hotTakeCount {
                return left.hotTakeCount < right.hotTakeCount
            }
            if abs(left.averageAbsoluteDeviation - right.averageAbsoluteDeviation) > 0.0001 {
                return left.averageAbsoluteDeviation < right.averageAbsoluteDeviation
            }
            return left.reviewerName.localizedCaseInsensitiveCompare(right.reviewerName) == .orderedDescending
        }
    }
}
