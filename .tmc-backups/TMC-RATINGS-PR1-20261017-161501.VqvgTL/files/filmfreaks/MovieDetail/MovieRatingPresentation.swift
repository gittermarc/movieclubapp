//
//  MovieRatingPresentation.swift
//  filmfreaks
//
//  Pure ordering and aggregation helpers for movie ratings.
//

import Foundation

nonisolated struct MovieRatingGroupSummary: Equatable, Sendable {
    let ratingsCount: Int
    let averageRating: Double?
    let averageFazit: Double?
    let fazitRatingsCount: Int
    let criterionAverages: [RatingCriterion: Double]
    let criterionRatingsCounts: [RatingCriterion: Int]

    init(ratings: [Rating]) {
        ratingsCount = ratings.count

        if ratings.isEmpty {
            averageRating = nil
        } else {
            let total = ratings
                .map(\.averageScoreNormalizedTo10)
                .reduce(0, +)
            averageRating = total / Double(ratings.count)
        }

        let fazitValues = ratings.compactMap(\.fazitScore).map { Double($0) }
        fazitRatingsCount = fazitValues.count
        averageFazit = fazitValues.isEmpty
            ? nil
            : fazitValues.reduce(0, +) / Double(fazitValues.count)

        var averages: [RatingCriterion: Double] = [:]
        var counts: [RatingCriterion: Int] = [:]

        for criterion in RatingCriterion.allCases {
            let values = ratings.compactMap { rating -> Double? in
                let score = rating.scores[criterion] ?? 0
                return score > 0 ? Double(score) : nil
            }

            counts[criterion] = values.count

            if !values.isEmpty {
                averages[criterion] = values.reduce(0, +) / Double(values.count)
            }
        }

        criterionAverages = averages
        criterionRatingsCounts = counts
    }
}

nonisolated enum MovieRatingPresentation {

    static func orderedRatings(
        _ ratings: [Rating],
        selectedUserID: UUID?,
        selectedUserName: String?
    ) -> [Rating] {
        ratings.sorted { lhs, rhs in
            let lhsIsCurrentUser = belongsToCurrentUser(
                lhs,
                selectedUserID: selectedUserID,
                selectedUserName: selectedUserName
            )
            let rhsIsCurrentUser = belongsToCurrentUser(
                rhs,
                selectedUserID: selectedUserID,
                selectedUserName: selectedUserName
            )

            if lhsIsCurrentUser != rhsIsCurrentUser {
                return lhsIsCurrentUser
            }

            let nameOrder = lhs.reviewerName.localizedCaseInsensitiveCompare(rhs.reviewerName)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }

            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }
    }

    static func belongsToCurrentUser(
        _ rating: Rating,
        selectedUserID: UUID?,
        selectedUserName: String?
    ) -> Bool {
        if let selectedUserID, rating.reviewerId == selectedUserID {
            return true
        }

        guard rating.reviewerId == nil,
              let selectedUserName else {
            return false
        }

        return rating.reviewerName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(
                selectedUserName.trimmingCharacters(in: .whitespacesAndNewlines)
            ) == .orderedSame
    }
}
