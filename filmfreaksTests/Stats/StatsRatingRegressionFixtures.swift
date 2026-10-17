import Foundation
@testable import filmfreaks

nonisolated enum StatsRatingRegressionFixtures {
    static let users: [User] = ["Alice", "Bob", "Clara", "Dan", "Erin", "Finn"].enumerated().map { index, name in
        let suffix = String(format: "%012d", index + 1)
        return User(id: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!, name: name)
    }

    static func rating(
        user index: Int,
        scores: [RatingCriterion: Int] = [:],
        fazit: Int? = nil,
        comment: String? = nil
    ) -> Rating {
        let user = users[index]
        return Rating(
            reviewerId: user.id,
            reviewerName: user.name,
            scores: scores,
            comment: comment,
            fazitScore: fazit
        )
    }

    static func movie(
        title: String = "Mixed contributions",
        ratings: [Rating],
        suggestedBy: String? = nil
    ) -> Movie {
        Movie(
            title: title,
            year: "2026",
            tmdbRating: 7.5,
            ratings: ratings,
            watchedDate: Date(timeIntervalSince1970: 1_767_268_800),
            suggestedBy: suggestedBy,
            addedAt: Date(timeIntervalSince1970: 1_766_404_800)
        )
    }

    static func snapshot(_ movies: [Movie], mode: RatingDisplayMode = .ratingAverage) -> StatsSnapshot {
        StatsSnapshotBuilder.computeSnapshot(
            movies: movies,
            users: users,
            ratingDisplayMode: mode,
            selectedRange: .all,
            selectedLocationFilter: nil
        )
    }

    static func equals(_ actual: Double?, _ expected: Double) -> Bool {
        guard let actual else { return false }
        return abs(actual - expected) < 0.0001
    }
}
