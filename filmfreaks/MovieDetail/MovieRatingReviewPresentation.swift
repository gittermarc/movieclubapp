//
//  MovieRatingReviewPresentation.swift
//  filmfreaks
//
//  Stable routing and text preparation for full rating reviews.
//

import Foundation

nonisolated struct MovieRatingReviewRoute: Hashable, Sendable {
    let ratingID: UUID

    init(ratingID: UUID) {
        self.ratingID = ratingID
    }

    init(rating: Rating) {
        ratingID = rating.id
    }
}

nonisolated enum MovieRatingReviewPresentation {

    static func normalizedComment(_ rawComment: String?) -> String? {
        guard let rawComment else {
            return nil
        }

        let normalizedLineEndings = rawComment
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let trimmedComment = normalizedLineEndings
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedComment.isEmpty ? nil : trimmedComment
    }

    static func comment(for rating: Rating) -> String? {
        normalizedComment(rating.comment)
    }

    static func rating(
        for route: MovieRatingReviewRoute,
        in ratings: [Rating]
    ) -> Rating? {
        ratings.first { $0.id == route.ratingID }
    }
}
