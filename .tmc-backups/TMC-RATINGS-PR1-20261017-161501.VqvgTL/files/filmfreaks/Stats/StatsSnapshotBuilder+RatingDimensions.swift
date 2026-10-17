//
//  StatsSnapshotBuilder+RatingDimensions.swift
//  filmfreaks
//
//  Rating-criterion insight computation for Stats.
//

import Foundation

nonisolated private enum StatsRatingDimensionsRules {
    static let minimumGroupRatingsPerCriterion = 6
    static let minimumReviewerRatingsPerCriterion = 3
    static let minimumMeaningfulReviewerDelta = 0.45
    static let meaningfulControversyThreshold = 0.45
}

nonisolated private struct StatsCriterionAggregate {
    let criterion: RatingCriterion
    var totalScore: Double
    var ratingsCount: Int
    var values: [Double]
}

nonisolated private struct StatsReviewerCriterionAggregate {
    let reviewerName: String
    let criterion: RatingCriterion
    var totalScore: Double
    var ratingsCount: Int
}

extension StatsSnapshotBuilder {

    nonisolated static func computeRatingDimensions(
        movies: [Movie],
        users: [User],
        reviewerKey: (Rating) -> String
    ) -> StatsRatingDimensionsSnapshot {
        let knownReviewerNames = knownCriterionReviewerNamesByKey(users: users)

        var criterionAggregates: [RatingCriterion: StatsCriterionAggregate] = [:]
        var reviewerCriterionAggregates: [String: StatsReviewerCriterionAggregate] = [:]

        for movie in movies {
            let ratingsByReviewer = latestRatingsByReviewer(
                movie: movie,
                knownReviewerNames: knownReviewerNames,
                reviewerKey: reviewerKey
            )

            for rating in ratingsByReviewer.values {
                for criterion in RatingCriterion.allCases {
                    let score = rating.scores[criterion] ?? 0
                    guard score > 0 else { continue }

                    let scoreValue = Double(score)

                    if var existing = criterionAggregates[criterion] {
                        existing.totalScore += scoreValue
                        existing.ratingsCount += 1
                        existing.values.append(scoreValue)
                        criterionAggregates[criterion] = existing
                    } else {
                        criterionAggregates[criterion] = StatsCriterionAggregate(
                            criterion: criterion,
                            totalScore: scoreValue,
                            ratingsCount: 1,
                            values: [scoreValue]
                        )
                    }

                    let reviewerCriterionKey = "\(rating.reviewerKey)|\(criterion.rawValue)"
                    if var existing = reviewerCriterionAggregates[reviewerCriterionKey] {
                        existing.totalScore += scoreValue
                        existing.ratingsCount += 1
                        reviewerCriterionAggregates[reviewerCriterionKey] = existing
                    } else {
                        reviewerCriterionAggregates[reviewerCriterionKey] = StatsReviewerCriterionAggregate(
                            reviewerName: rating.reviewerName,
                            criterion: criterion,
                            totalScore: scoreValue,
                            ratingsCount: 1
                        )
                    }
                }
            }
        }

        let strongestCriterion = strongestCriterion(from: criterionAggregates)
        let weakestCriterion = weakestCriterion(from: criterionAggregates)
        let mostControversialCriterion = mostControversialCriterion(from: criterionAggregates)
        let reviewerHighlight = reviewerHighlight(
            criterionAggregates: criterionAggregates,
            reviewerCriterionAggregates: reviewerCriterionAggregates
        )

        return StatsRatingDimensionsSnapshot(
            strongestCriterion: strongestCriterion,
            weakestCriterion: weakestCriterion,
            mostControversialCriterion: mostControversialCriterion,
            reviewerHighlight: reviewerHighlight
        )
    }

    nonisolated private static func knownCriterionReviewerNamesByKey(users: [User]) -> [String: String] {
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

    nonisolated private static func latestRatingsByReviewer(
        movie: Movie,
        knownReviewerNames: [String: String],
        reviewerKey: (Rating) -> String
    ) -> [String: (reviewerKey: String, reviewerName: String, scores: [RatingCriterion: Int], updatedAt: Date?)] {
        var ratingsByReviewer: [String: (reviewerKey: String, reviewerName: String, scores: [RatingCriterion: Int], updatedAt: Date?)] = [:]

        for rating in movie.ratings {
            let key = reviewerKey(rating)
            let reviewerName = resolveCriterionReviewerName(
                key: key,
                rawReviewerName: rating.reviewerName,
                knownReviewerNames: knownReviewerNames
            )

            if let existing = ratingsByReviewer[key] {
                if shouldReplaceCriterionRating(existingUpdatedAt: existing.updatedAt, candidateUpdatedAt: rating.updatedAt) {
                    ratingsByReviewer[key] = (
                        reviewerKey: key,
                        reviewerName: reviewerName,
                        scores: rating.scores,
                        updatedAt: rating.updatedAt
                    )
                }
            } else {
                ratingsByReviewer[key] = (
                    reviewerKey: key,
                    reviewerName: reviewerName,
                    scores: rating.scores,
                    updatedAt: rating.updatedAt
                )
            }
        }

        return ratingsByReviewer
    }

    nonisolated private static func resolveCriterionReviewerName(
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

    nonisolated private static func shouldReplaceCriterionRating(
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

    nonisolated private static func strongestCriterion(
        from criterionAggregates: [RatingCriterion: StatsCriterionAggregate]
    ) -> StatsCriterionAverageInsight? {
        let candidates = criterionAggregates.values.compactMap { aggregate -> StatsCriterionAverageInsight? in
            guard aggregate.ratingsCount >= StatsRatingDimensionsRules.minimumGroupRatingsPerCriterion else { return nil }
            return StatsCriterionAverageInsight(
                criterion: aggregate.criterion,
                averageScore: aggregate.totalScore / Double(aggregate.ratingsCount),
                ratingsCount: aggregate.ratingsCount
            )
        }

        return candidates.max { left, right in
            if abs(left.averageScore - right.averageScore) > 0.0001 {
                return left.averageScore < right.averageScore
            }
            if left.ratingsCount != right.ratingsCount {
                return left.ratingsCount < right.ratingsCount
            }
            return criterionSortIndex(left.criterion) > criterionSortIndex(right.criterion)
        }
    }

    nonisolated private static func weakestCriterion(
        from criterionAggregates: [RatingCriterion: StatsCriterionAggregate]
    ) -> StatsCriterionAverageInsight? {
        let candidates = criterionAggregates.values.compactMap { aggregate -> StatsCriterionAverageInsight? in
            guard aggregate.ratingsCount >= StatsRatingDimensionsRules.minimumGroupRatingsPerCriterion else { return nil }
            return StatsCriterionAverageInsight(
                criterion: aggregate.criterion,
                averageScore: aggregate.totalScore / Double(aggregate.ratingsCount),
                ratingsCount: aggregate.ratingsCount
            )
        }

        guard candidates.count >= 2 else { return nil }

        return candidates.min { left, right in
            if abs(left.averageScore - right.averageScore) > 0.0001 {
                return left.averageScore < right.averageScore
            }
            if left.ratingsCount != right.ratingsCount {
                return left.ratingsCount > right.ratingsCount
            }
            return criterionSortIndex(left.criterion) < criterionSortIndex(right.criterion)
        }
    }

    nonisolated private static func mostControversialCriterion(
        from criterionAggregates: [RatingCriterion: StatsCriterionAggregate]
    ) -> StatsCriterionControversyInsight? {
        let candidates = criterionAggregates.values.compactMap { aggregate -> StatsCriterionControversyInsight? in
            guard aggregate.ratingsCount >= StatsRatingDimensionsRules.minimumGroupRatingsPerCriterion else { return nil }
            let deviation = standardDeviation(aggregate.values)
            return StatsCriterionControversyInsight(
                criterion: aggregate.criterion,
                standardDeviation: deviation,
                ratingsCount: aggregate.ratingsCount,
                isMeaningfullyControversial: deviation >= StatsRatingDimensionsRules.meaningfulControversyThreshold
            )
        }

        return candidates.max { left, right in
            if abs(left.standardDeviation - right.standardDeviation) > 0.0001 {
                return left.standardDeviation < right.standardDeviation
            }
            if left.ratingsCount != right.ratingsCount {
                return left.ratingsCount < right.ratingsCount
            }
            return criterionSortIndex(left.criterion) > criterionSortIndex(right.criterion)
        }
    }

    nonisolated private static func reviewerHighlight(
        criterionAggregates: [RatingCriterion: StatsCriterionAggregate],
        reviewerCriterionAggregates: [String: StatsReviewerCriterionAggregate]
    ) -> StatsCriterionReviewerHighlight? {
        let groupAveragesByCriterion: [RatingCriterion: (average: Double, ratingsCount: Int)] = criterionAggregates.reduce(into: [:]) { partialResult, entry in
            let aggregate = entry.value
            guard aggregate.ratingsCount >= StatsRatingDimensionsRules.minimumGroupRatingsPerCriterion else { return }
            partialResult[entry.key] = (
                average: aggregate.totalScore / Double(aggregate.ratingsCount),
                ratingsCount: aggregate.ratingsCount
            )
        }

        let candidates = reviewerCriterionAggregates.values.compactMap { aggregate -> StatsCriterionReviewerHighlight? in
            guard aggregate.ratingsCount >= StatsRatingDimensionsRules.minimumReviewerRatingsPerCriterion else { return nil }
            guard let groupAggregate = groupAveragesByCriterion[aggregate.criterion] else { return nil }

            let reviewerAverage = aggregate.totalScore / Double(aggregate.ratingsCount)
            let averageDelta = reviewerAverage - groupAggregate.average
            guard averageDelta >= StatsRatingDimensionsRules.minimumMeaningfulReviewerDelta else { return nil }

            return StatsCriterionReviewerHighlight(
                reviewerName: aggregate.reviewerName,
                criterion: aggregate.criterion,
                reviewerAverageScore: reviewerAverage,
                groupAverageScore: groupAggregate.average,
                ratingsCount: aggregate.ratingsCount,
                averageDelta: averageDelta
            )
        }

        return candidates.max { left, right in
            if abs(left.averageDelta - right.averageDelta) > 0.0001 {
                return left.averageDelta < right.averageDelta
            }
            if left.ratingsCount != right.ratingsCount {
                return left.ratingsCount < right.ratingsCount
            }
            if left.reviewerName.localizedCaseInsensitiveCompare(right.reviewerName) != .orderedSame {
                return left.reviewerName.localizedCaseInsensitiveCompare(right.reviewerName) == .orderedDescending
            }
            return criterionSortIndex(left.criterion) > criterionSortIndex(right.criterion)
        }
    }

    nonisolated private static func criterionSortIndex(_ criterion: RatingCriterion) -> Int {
        RatingCriterion.allCases.firstIndex(of: criterion) ?? Int.max
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
