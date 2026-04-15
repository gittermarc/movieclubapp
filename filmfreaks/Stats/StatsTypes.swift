//
//  StatsTypes.swift
//  filmfreaks
//
//  Extracted from StatsView.swift to keep the dashboard view maintainable.
//

import Foundation

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case last30 = "Letzte 30 Tage"
    case last90 = "Letzte 90 Tage"
    case thisYear = "Dieses Jahr"
    case all = "Gesamte Zeit"

    var id: Self { self }
}

enum StatsCriticGapKind: String, CaseIterable, Identifiable {
    /// Eure Gruppe bewertet höher als TMDB ("underrated" bei TMDB).
    case groupHigher = "Eure Gruppe > TMDB"
    /// TMDB bewertet höher als eure Gruppe ("overrated" bei TMDB).
    case groupLower = "TMDB > Eure Gruppe"

    var id: Self { self }

    var headline: String {
        switch self {
        case .groupHigher:
            return "Eure Gruppe findet besser als TMDB"
        case .groupLower:
            return "TMDB findet besser als eure Gruppe"
        }
    }

    var sheetTitle: String {
        switch self {
        case .groupHigher:
            return "Underrated bei TMDB"
        case .groupLower:
            return "Overrated bei TMDB"
        }
    }

    var helpText: String {
        switch self {
        case .groupHigher:
            return "Filme, die eure Gruppe deutlich höher bewertet als der TMDB-Score."
        case .groupLower:
            return "Filme, die TMDB deutlich höher bewertet als eure Gruppe."
        }
    }
}

enum StatsDrilldown: Identifiable {
    case month(Date)
    case location(String)
    case suggestedBy(String)
    case critics(StatsCriticGapKind)

    var id: String {
        switch self {
        case .month(let date):
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            return "month_\(y)_\(m)"
        case .location(let loc):
            return "location_\(loc)"
        case .suggestedBy(let name):
            return "suggestedBy_\(name)"
        case .critics(let kind):
            return "critics_\(kind.rawValue)"
        }
    }
}

struct GenreDrilldown: Identifiable, Hashable {
    let genre: String
    var id: String { genre }
}

struct ActorEntry: Identifiable, Hashable {
    let personId: Int
    let name: String
    let count: Int
    var id: Int { personId }
}

struct StatsMonthTrend: Identifiable, Hashable {
    let monthStart: Date
    let movieCount: Int
    let averageRating: Double?

    var id: Date { monthStart }
}

struct MovieHighlight: Identifiable {
    let movie: Movie
    let value: Double

    var id: UUID { movie.id }
}



nonisolated struct StatsCriterionAverageInsight: Hashable {
    let criterion: RatingCriterion
    let averageScore: Double
    let ratingsCount: Int
}

nonisolated struct StatsCriterionControversyInsight: Hashable {
    let criterion: RatingCriterion
    let standardDeviation: Double
    let ratingsCount: Int
    let isMeaningfullyControversial: Bool
}

nonisolated struct StatsCriterionReviewerHighlight: Hashable {
    let reviewerName: String
    let criterion: RatingCriterion
    let reviewerAverageScore: Double
    let groupAverageScore: Double
    let ratingsCount: Int
    let averageDelta: Double
}

nonisolated struct StatsRatingDimensionsSnapshot {
    let strongestCriterion: StatsCriterionAverageInsight?
    let weakestCriterion: StatsCriterionAverageInsight?
    let mostControversialCriterion: StatsCriterionControversyInsight?
    let reviewerHighlight: StatsCriterionReviewerHighlight?

    static let empty = StatsRatingDimensionsSnapshot(
        strongestCriterion: nil,
        weakestCriterion: nil,
        mostControversialCriterion: nil,
        reviewerHighlight: nil
    )
}

nonisolated struct StatsTastePairInsight: Hashable {
    let firstReviewerName: String
    let secondReviewerName: String
    let sharedMoviesCount: Int
    let averageDifference: Double
}

nonisolated struct StatsReviewerBiasInsight: Hashable {
    let reviewerName: String
    let comparableRatingsCount: Int
    let averageBias: Double
}

nonisolated struct StatsHotTakeInsight: Hashable {
    let reviewerName: String
    let hotTakeCount: Int
    let comparableRatingsCount: Int
    let hotTakeRate: Double
    let averageAbsoluteDeviation: Double
}

nonisolated struct StatsTasteDynamicsSnapshot {
    let tasteTwins: StatsTastePairInsight?
    let frictionPair: StatsTastePairInsight?
    let strictestReviewer: StatsReviewerBiasInsight?
    let mostGenerousReviewer: StatsReviewerBiasInsight?
    let hotTakeReviewer: StatsHotTakeInsight?

    static let empty = StatsTasteDynamicsSnapshot(
        tasteTwins: nil,
        frictionPair: nil,
        strictestReviewer: nil,
        mostGenerousReviewer: nil,
        hotTakeReviewer: nil
    )
}

nonisolated struct StatsPickInsight {
    let movie: Movie
    let averageRating: Double
    let ratingsCount: Int
    let standardDeviation: Double
    let recommendationScore: Double
}

nonisolated struct StatsPickInsightsSnapshot {
    let safePick: StatsPickInsight?
    let daringPick: StatsPickInsight?
    let crowdPleaser: StatsPickInsight?

    static let empty = StatsPickInsightsSnapshot(
        safePick: nil,
        daringPick: nil,
        crowdPleaser: nil
    )
}


nonisolated struct StatsSuggestionQualityInsight {
    let suggesterName: String
    let ratedSuggestionsCount: Int
    let averageGroupRating: Double
    let crowdPleaserCount: Int
    let crowdPleaserRate: Double
    let controversialCount: Int
    let controversialRate: Double
}

nonisolated struct StatsSuggestionWatchTimingInsight {
    let suggesterName: String
    let datedSuggestionsCount: Int
    let averageDaysToWatch: Double
    let averageGroupRating: Double
    let ratedSuggestionsCount: Int
    let ratingDisplayMode: RatingDisplayMode
}

nonisolated struct StatsSuggestionQualitySnapshot {
    let bestAverageRatingSuggester: StatsSuggestionQualityInsight?
    let bestHitRateSuggester: StatsSuggestionQualityInsight?
    let mostControversialSuggester: StatsSuggestionQualityInsight?
    let fastestToWatchSuggester: StatsSuggestionWatchTimingInsight?

    static let empty = StatsSuggestionQualitySnapshot(
        bestAverageRatingSuggester: nil,
        bestHitRateSuggester: nil,
        mostControversialSuggester: nil,
        fastestToWatchSuggester: nil
    )
}

struct CriticGapEntry: Identifiable {
    let movie: Movie
    let groupAverage: Double
    let tmdbAverage: Double

    /// groupAverage - tmdbAverage (positiv: Gruppe höher, negativ: TMDB höher)
    let delta: Double

    var id: UUID { movie.id }
}
