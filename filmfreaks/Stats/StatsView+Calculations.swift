//
//  StatsView+Calculations.swift
//  filmfreaks
//
//  Lightweight accessors for cached StatsViewModel snapshot.
//

import Foundation

extension StatsView {

    // MARK: - Hero Copy

    var heroTitle: String {
        if let groupName = movieStore.currentGroupName {
            return "\(groupName) – Überblick"
        }
        return "Eure Filmgruppe – Überblick"
    }

    var heroSubtitle: String {
        let rangeText = selectedRange.rawValue
        let locText = selectedLocationFilter ?? "Alle Orte"
        return "\(rangeText) • \(locText)"
    }

    // MARK: - Basis & Filter (cached)

    var moviesForCurrentTimeRange: [Movie] {
        viewModel.snapshot.moviesForCurrentTimeRange
    }

    var filteredMovies: [Movie] {
        viewModel.snapshot.filteredMovies
    }

    var availableLocations: [String] {
        viewModel.snapshot.availableLocations
    }

    func normalizedLocation(for movie: Movie) -> String {
        let trimmed = movie.watchedLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Ohne Angabe" : trimmed
    }

    // MARK: - KPIs (cached)

    var totalRatingsCount: Int {
        viewModel.snapshot.totalRatingsCount
    }

    var activeReviewersCount: Int {
        viewModel.snapshot.activeReviewersCount
    }

    var ratedMoviesCount: Int {
        viewModel.snapshot.ratedMoviesCount
    }

    var ratingCoveragePercentText: String {
        viewModel.snapshot.ratingCoveragePercentText
    }

    // MARK: - Group Health (cached)

    var memberKeysSet: Set<String> {
        viewModel.snapshot.memberKeysSet
    }

    var activeReviewerKeysSet: Set<String> {
        viewModel.snapshot.activeReviewerKeysSet
    }

    var unratedMoviesCount: Int {
        viewModel.snapshot.unratedMoviesCount
    }

    var moviesRatedByAllActiveMembersCount: Int {
        viewModel.snapshot.moviesRatedByAllActiveMembersCount
    }

    var moviesRatedByAllMembersCount: Int {
        viewModel.snapshot.moviesRatedByAllMembersCount
    }

    // MARK: - Aggregationen (cached)

    var overallAverageRating: Double? {
        viewModel.snapshot.overallAverageRating
    }

    var mostRecentWatchedDate: Date? {
        viewModel.snapshot.mostRecentWatchedDate
    }

    var monthTrends: [StatsMonthTrend] {
        viewModel.snapshot.monthTrends
    }

    var moviesPerMonth: [(date: Date, count: Int)] {
        viewModel.snapshot.moviesPerMonth
    }

    var topRatedHighlights: [MovieHighlight] {
        viewModel.snapshot.topRatedHighlights
    }

    var controversialHighlights: [MovieHighlight] {
        viewModel.snapshot.controversialHighlights
    }

    // MARK: - Kritik vs TMDB (cached)

    var criticGapEntries: [CriticGapEntry] {
        viewModel.snapshot.criticGapEntries
    }

    var criticGapGroupHigher: [CriticGapEntry] {
        viewModel.snapshot.criticGapGroupHigher
    }

    var criticGapGroupLower: [CriticGapEntry] {
        viewModel.snapshot.criticGapGroupLower
    }

    // MARK: - Genres / Cast / Orte / Vorschläge (cached)

    var moviesByGenreRaw: [(genre: String, count: Int)] {
        viewModel.snapshot.moviesByGenreRaw
    }

    var genresDisplaySource: [(genre: String, count: Int)] {
        genreDisplayOrder.isEmpty ? moviesByGenreRaw : genreDisplayOrder
    }

    var actorsByCountRaw: [ActorEntry] {
        viewModel.snapshot.actorsByCountRaw
    }

    var actorsDisplaySource: [ActorEntry] {
        actorsByCountRaw
    }

    var moviesByLocation: [(location: String, count: Int)] {
        viewModel.snapshot.moviesByLocation
    }

    var suggestionsByUser: [(name: String, count: Int)] {
        viewModel.snapshot.suggestionsByUser
    }

    var strongestCriterion: StatsCriterionAverageInsight? {
        viewModel.snapshot.strongestCriterion
    }

    var weakestCriterion: StatsCriterionAverageInsight? {
        viewModel.snapshot.weakestCriterion
    }

    var mostControversialCriterion: StatsCriterionControversyInsight? {
        viewModel.snapshot.mostControversialCriterion
    }

    var criterionReviewerHighlight: StatsCriterionReviewerHighlight? {
        viewModel.snapshot.criterionReviewerHighlight
    }

    var tasteTwins: StatsTastePairInsight? {
        viewModel.snapshot.tasteTwins
    }

    var frictionPair: StatsTastePairInsight? {
        viewModel.snapshot.frictionPair
    }

    var strictestReviewer: StatsReviewerBiasInsight? {
        viewModel.snapshot.strictestReviewer
    }

    var mostGenerousReviewer: StatsReviewerBiasInsight? {
        viewModel.snapshot.mostGenerousReviewer
    }

    var hotTakeReviewer: StatsHotTakeInsight? {
        viewModel.snapshot.hotTakeReviewer
    }

    var safePick: StatsPickInsight? {
        viewModel.snapshot.safePick
    }

    var daringPick: StatsPickInsight? {
        viewModel.snapshot.daringPick
    }

    var crowdPleaser: StatsPickInsight? {
        viewModel.snapshot.crowdPleaser
    }

    func statsForUser(_ user: User) -> (movieCount: Int, ratingsCount: Int, averageRating: Double?) {
        guard let s = viewModel.snapshot.userStatsByUserId[user.id] else {
            return (0, 0, nil)
        }
        return (s.movieCount, s.ratingsCount, s.averageRating)
    }
}
