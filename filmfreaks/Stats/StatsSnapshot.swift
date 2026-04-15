//
//  StatsSnapshot.swift
//  filmfreaks
//
//  Value types for the debounced/off-main Stats snapshot pipeline.
//

import Foundation

struct StatsUserStats: Equatable {
    var movieCount: Int
    var ratingsCount: Int
    var averageRating: Double?
}

/// Cached, render-ready aggregation results.
///
/// Note: Intentionally **not** `Equatable`.
/// Several contained types (e.g. domain models / highlight structs) are not equatable,
/// and SwiftUI does not require `Equatable` for `@Published` outputs.
struct StatsSnapshot {
    var moviesForCurrentTimeRange: [Movie]
    var filteredMovies: [Movie]
    var availableLocations: [String]

    var totalRatingsCount: Int
    var activeReviewersCount: Int
    var ratedMoviesCount: Int
    var ratingCoveragePercentText: String

    var memberKeysSet: Set<String>
    var activeReviewerKeysSet: Set<String>
    var unratedMoviesCount: Int
    var moviesRatedByAllActiveMembersCount: Int
    var moviesRatedByAllMembersCount: Int

    var overallAverageRating: Double?
    var mostRecentWatchedDate: Date?
    var monthTrends: [StatsMonthTrend]
    var moviesPerMonth: [(date: Date, count: Int)]
    var topRatedHighlights: [MovieHighlight]
    var controversialHighlights: [MovieHighlight]
    var criticGapEntries: [CriticGapEntry]
    var criticGapGroupHigher: [CriticGapEntry]
    var criticGapGroupLower: [CriticGapEntry]

    var moviesByGenreRaw: [(genre: String, count: Int)]
    var actorsByCountRaw: [ActorEntry]
    var moviesByLocation: [(location: String, count: Int)]
    var suggestionsByUser: [(name: String, count: Int)]

    var strongestCriterion: StatsCriterionAverageInsight?
    var weakestCriterion: StatsCriterionAverageInsight?
    var mostControversialCriterion: StatsCriterionControversyInsight?
    var criterionReviewerHighlight: StatsCriterionReviewerHighlight?

    var tasteTwins: StatsTastePairInsight?
    var frictionPair: StatsTastePairInsight?
    var strictestReviewer: StatsReviewerBiasInsight?
    var mostGenerousReviewer: StatsReviewerBiasInsight?
    var hotTakeReviewer: StatsHotTakeInsight?

    var safePick: StatsPickInsight?
    var daringPick: StatsPickInsight?
    var crowdPleaser: StatsPickInsight?

    var userStatsByUserId: [UUID: StatsUserStats]

    static let empty = StatsSnapshot(
        moviesForCurrentTimeRange: [],
        filteredMovies: [],
        availableLocations: [],
        totalRatingsCount: 0,
        activeReviewersCount: 0,
        ratedMoviesCount: 0,
        ratingCoveragePercentText: "0%",
        memberKeysSet: [],
        activeReviewerKeysSet: [],
        unratedMoviesCount: 0,
        moviesRatedByAllActiveMembersCount: 0,
        moviesRatedByAllMembersCount: 0,
        overallAverageRating: nil,
        mostRecentWatchedDate: nil,
        monthTrends: [],
        moviesPerMonth: [],
        topRatedHighlights: [],
        controversialHighlights: [],
        criticGapEntries: [],
        criticGapGroupHigher: [],
        criticGapGroupLower: [],
        moviesByGenreRaw: [],
        actorsByCountRaw: [],
        moviesByLocation: [],
        suggestionsByUser: [],
        strongestCriterion: nil,
        weakestCriterion: nil,
        mostControversialCriterion: nil,
        criterionReviewerHighlight: nil,
        tasteTwins: nil,
        frictionPair: nil,
        strictestReviewer: nil,
        mostGenerousReviewer: nil,
        hotTakeReviewer: nil,
        safePick: nil,
        daringPick: nil,
        crowdPleaser: nil,
        userStatsByUserId: [:]
    )
}
