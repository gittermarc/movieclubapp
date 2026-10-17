//
//  MovieRatingPresentation.swift
//  filmfreaks
//
//  Pure ordering and aggregation helpers for movie ratings.
//

import Foundation

nonisolated struct MovieRatingGroupSummary: Equatable, Sendable {
    /// All saved contributions, including reviews without a numeric score.
    let ratingsCount: Int
    let criteriaRatingsCount: Int
    let averageRating: Double?
    let averageFazit: Double?
    let fazitRatingsCount: Int
    let criterionAverages: [RatingCriterion: Double]
    let criterionRatingsCounts: [RatingCriterion: Int]

    init(ratings: [Rating]) {
        ratingsCount = ratings.count

        criteriaRatingsCount = ratings.compactMap(\.averageScoreNormalizedTo10).count
        averageRating = RatingCalculation.criteriaAverage(ratings: ratings)

        fazitRatingsCount = ratings.compactMap(\.fazitScore).count
        averageFazit = RatingCalculation.fazitAverage(ratings: ratings)

        var averages: [RatingCriterion: Double] = [:]
        var counts: [RatingCriterion: Int] = [:]

        for criterion in RatingCriterion.allCases {
            let values = ratings.compactMap { rating -> Double? in
                let score = rating.scores[criterion] ?? 0
                return score > 0 ? Double(score) : nil
            }

            counts[criterion] = values.count

            averages[criterion] = RatingCalculation.average(values)
        }

        criterionAverages = averages
        criterionRatingsCounts = counts
    }
}

nonisolated enum MovieRatingPresentation {

    static func scoreText(_ score: Double?) -> String {
        guard let score else {
            return "Nicht vergeben"
        }

        return String(format: "%.1f / 10", score)
    }

    static func missingCriteriaText(ratingsCount: Int) -> String {
        ratingsCount == 0 ? "Noch keine Bewertungen" : "Kriterien nicht vergeben"
    }

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
