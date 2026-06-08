//
//  RatingDeleteKeyIndex.swift
//  filmfreaks
//

import Foundation

/// Small lookup index for CloudKit rating deletes.
///
/// Zone-change deletes arrive as flat `(movieId, reviewerKey)` pairs. The movie sync merge path
/// applies those deletes to every locally visible movie. Indexing them once by movie ID avoids
/// repeatedly scanning the full delete list for each watched/backlog movie.
struct RatingDeleteKeyIndex: Equatable {
    private let reviewerKeysByMovieId: [UUID: Set<String>]

    init(deletedKeys: [(movieId: UUID, reviewerKey: String)]) {
        var grouped: [UUID: Set<String>] = [:]
        grouped.reserveCapacity(deletedKeys.count)

        for key in deletedKeys {
            let reviewerKey = Self.normalizedReviewerKey(key.reviewerKey)
            guard !reviewerKey.isEmpty else { continue }
            grouped[key.movieId, default: []].insert(reviewerKey)
        }

        self.reviewerKeysByMovieId = grouped
    }

    var isEmpty: Bool {
        reviewerKeysByMovieId.isEmpty
    }

    func reviewerKeys(for movieId: UUID) -> Set<String> {
        reviewerKeysByMovieId[movieId] ?? []
    }

    func contains(movieId: UUID, reviewerKey: String) -> Bool {
        reviewerKeys(for: movieId).contains(Self.normalizedReviewerKey(reviewerKey))
    }

    func removingDeletedRatings(
        from ratings: [Rating],
        movieId: UUID,
        reviewerKey: (Rating) -> String
    ) -> [Rating] {
        let deletedReviewerKeys = reviewerKeys(for: movieId)
        guard !deletedReviewerKeys.isEmpty else { return ratings }

        return ratings.filter { rating in
            !deletedReviewerKeys.contains(Self.normalizedReviewerKey(reviewerKey(rating)))
        }
    }

    private static func normalizedReviewerKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
