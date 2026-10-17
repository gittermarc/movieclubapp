import Foundation

/// Pure rating arithmetic. Absence is represented by nil, never by a zero score.
nonisolated enum RatingCalculation {
    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func criteriaAverageStars(scores: [RatingCriterion: Int]) -> Double? {
        average(scores.values.filter { $0 > 0 }.map { Double($0) })
    }

    static func criteriaScore(scores: [RatingCriterion: Int]) -> Double? {
        criteriaAverageStars(scores: scores).map { ($0 / 3.0) * 10.0 }
    }

    /// Keep existing stored Fazit values unchanged; this is not a migration or validation pass.
    static func fazitValue(_ score: Int?) -> Double? {
        score.map { Double($0) }
    }

    /// Each person with criteria counts once, regardless of how many criteria they filled in.
    static func criteriaAverage(ratings: [Rating]) -> Double? {
        average(ratings.compactMap(\.averageScoreNormalizedTo10))
    }

    static func fazitAverage(ratings: [Rating]) -> Double? {
        average(ratings.compactMap { fazitValue($0.fazitScore) })
    }

    /// Individual statistics and activity use a per-person Fazit fallback.
    /// Movie.groupAverage instead falls back only when the entire movie has no Fazit.
    static func value(for rating: Rating, displayMode: RatingDisplayMode) -> Double? {
        switch displayMode {
        case .ratingAverage:
            return rating.averageScoreNormalizedTo10
        case .fazitAverage:
            return fazitValue(rating.fazitScore) ?? rating.averageScoreNormalizedTo10
        }
    }
}
