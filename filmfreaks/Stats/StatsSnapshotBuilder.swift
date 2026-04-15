//
//  StatsSnapshotBuilder.swift
//  filmfreaks
//
//  Pure (non-UI) snapshot computation for Stats.
//  Moved out of StatsViewModel so the work can run off-main.
//

import Foundation

enum StatsSnapshotBuilder {

    // The project uses SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
    // These helpers are intentionally pure and must stay callable from detached tasks.
    nonisolated static func sortActors(
        actors: [ActorEntry],
        popularityByPersonId: [Int: Double]
    ) -> [ActorEntry] {
        actors.sorted { a, b in
            if a.count != b.count { return a.count > b.count }

            let popA = popularityByPersonId[a.personId] ?? 0
            let popB = popularityByPersonId[b.personId] ?? 0
            if popA != popB { return popA > popB }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    nonisolated static func computeSnapshot(
        movies: [Movie],
        users: [User],
        ratingDisplayMode: RatingDisplayMode,
        selectedRange: StatsTimeRange,
        selectedLocationFilter: String?
    ) -> StatsSnapshot {
        let calendar = Calendar.current
        let today = Date()

        let moviesForCurrentTimeRange: [Movie] = movies.compactMap { movie in
            guard let date = movie.watchedDate else { return nil }

            switch selectedRange {
            case .all:
                return movie
            case .thisYear:
                if calendar.isDate(date, equalTo: today, toGranularity: .year) { return movie }
            case .last30:
                if let from = calendar.date(byAdding: .day, value: -30, to: today), date >= from { return movie }
            case .last90:
                if let from = calendar.date(byAdding: .day, value: -90, to: today), date >= from { return movie }
            }
            return nil
        }

        func normalizedLocation(for movie: Movie) -> String {
            let trimmed = movie.watchedLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "Ohne Angabe" : trimmed
        }

        let filteredMovies: [Movie]
        if let loc = selectedLocationFilter {
            filteredMovies = moviesForCurrentTimeRange.filter { normalizedLocation(for: $0) == loc }
        } else {
            filteredMovies = moviesForCurrentTimeRange
        }

        let availableLocations: [String] = {
            let locations = moviesForCurrentTimeRange.map { normalizedLocation(for: $0) }
            return Array(Set(locations)).sorted()
        }()

        func displayedScore(for rating: Rating) -> Double? {
            switch ratingDisplayMode {
            case .ratingAverage:
                return rating.averageScoreNormalizedTo10
            case .fazitAverage:
                if let f = rating.fazitScore { return Double(f) }
                let v = rating.averageScoreNormalizedTo10
                return v > 0 ? v : nil
            }
        }

        func reviewerKey(for rating: Rating) -> String {
            if let rid = rating.reviewerId {
                return "id:\(rid.uuidString.lowercased())"
            }
            let canon = rating.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !canon.isEmpty, let match = users.first(where: {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == canon
            }) {
                return "id:\(match.id.uuidString.lowercased())"
            }
            return "name:\(canon)"
        }

        var memberKeysSet: Set<String> = []
        for u in users {
            memberKeysSet.insert("id:\(u.id.uuidString.lowercased())")
            let nameKey = u.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !nameKey.isEmpty {
                memberKeysSet.insert("name:\(nameKey)")
            }
        }

        let activeReviewerKeysSet: Set<String> = Set(
            filteredMovies.flatMap { $0.ratings.map { reviewerKey(for: $0) } }
        )

        let totalRatingsCount = filteredMovies.reduce(0) { $0 + $1.ratings.count }
        let activeReviewersCount = Set(filteredMovies.flatMap { $0.ratings.map { reviewerKey(for: $0) } }).count
        let ratedMoviesCount = filteredMovies.filter { !$0.ratings.isEmpty }.count
        let unratedMoviesCount = max(0, filteredMovies.count - ratedMoviesCount)

        let ratingCoveragePercentText: String = {
            guard filteredMovies.count > 0 else { return "0%" }
            let pct = (Double(ratedMoviesCount) / Double(filteredMovies.count)) * 100.0
            return String(format: "%.0f%% bewertet", pct)
        }()

        let moviesRatedByAllActiveMembersCount: Int = {
            let active = activeReviewerKeysSet
            guard !active.isEmpty else { return 0 }
            return filteredMovies.filter { movie in
                let reviewers = Set(movie.ratings.map { reviewerKey(for: $0) })
                return active.isSubset(of: reviewers)
            }.count
        }()

        let moviesRatedByAllMembersCount: Int = {
            let members = memberKeysSet
            guard !members.isEmpty else { return 0 }
            return filteredMovies.filter { movie in
                let reviewers = Set(movie.ratings.map { reviewerKey(for: $0) })
                return members.isSubset(of: reviewers)
            }.count
        }()

        let overallAverageRating: Double? = {
            let allScores = filteredMovies.flatMap { movie in
                movie.ratings.compactMap { displayedScore(for: $0) }
            }
            guard !allScores.isEmpty else { return nil }
            let total = allScores.reduce(0, +)
            return total / Double(allScores.count)
        }()

        let mostRecentWatchedDate: Date? = filteredMovies.compactMap { $0.watchedDate }.max()

        let monthTrends: [StatsMonthTrend] = {
            var buckets: [Date: (movies: Int, scores: [Double])] = [:]
            for movie in filteredMovies {
                guard let date = movie.watchedDate else { continue }
                guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { continue }

                var entry = buckets[monthStart] ?? (movies: 0, scores: [])
                entry.movies += 1
                entry.scores.append(contentsOf: movie.ratings.compactMap { displayedScore(for: $0) })
                buckets[monthStart] = entry
            }

            let result = buckets.map { (monthStart, data) -> StatsMonthTrend in
                let avg: Double?
                if data.scores.isEmpty {
                    avg = nil
                } else {
                    avg = data.scores.reduce(0, +) / Double(data.scores.count)
                }
                return StatsMonthTrend(monthStart: monthStart, movieCount: data.movies, averageRating: avg)
            }
            return result.sorted { $0.monthStart < $1.monthStart }
        }()

        let moviesPerMonth: [(date: Date, count: Int)] = monthTrends
            .map { (date: $0.monthStart, count: $0.movieCount) }
            .sorted { $0.date > $1.date }

        let topRatedHighlights: [MovieHighlight] = {
            let base = filteredMovies.compactMap { movie -> MovieHighlight? in
                guard let avg = movie.groupAverage(for: ratingDisplayMode) else { return nil }
                return MovieHighlight(movie: movie, value: avg)
            }
            return base.sorted { $0.value > $1.value }.prefix(5).map { $0 }
        }()

        func standardDeviation(_ values: [Double]) -> Double {
            guard values.count >= 2 else { return 0 }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values
                .map { ($0 - mean) * ($0 - mean) }
                .reduce(0, +) / Double(values.count)
            return sqrt(variance)
        }

        let controversialHighlights: [MovieHighlight] = {
            let base = filteredMovies.compactMap { movie -> MovieHighlight? in
                let values = movie.ratings.compactMap { displayedScore(for: $0) }
                guard values.count >= 2 else { return nil }
                return MovieHighlight(movie: movie, value: standardDeviation(values))
            }
            return base.sorted { $0.value > $1.value }.prefix(5).map { $0 }
        }()

        let criticGapEntries: [CriticGapEntry] = filteredMovies.compactMap { movie in
            guard let groupAvg = movie.groupAverage(for: ratingDisplayMode) else { return nil }
            guard let tmdb = movie.tmdbRating else { return nil }
            let delta = groupAvg - tmdb
            return CriticGapEntry(movie: movie, groupAverage: groupAvg, tmdbAverage: tmdb, delta: delta)
        }

        func criticGapEntriesFiltered(kind: StatsCriticGapKind) -> [CriticGapEntry] {
            let minInterestingDelta = 0.8
            let eps = 0.0001

            let base: [CriticGapEntry]
            switch kind {
            case .groupHigher:
                let strong = criticGapEntries.filter { $0.delta >= minInterestingDelta }
                base = strong.isEmpty ? criticGapEntries.filter { $0.delta > eps } : strong
                return base.sorted { $0.delta > $1.delta }
            case .groupLower:
                let strong = criticGapEntries.filter { $0.delta <= -minInterestingDelta }
                base = strong.isEmpty ? criticGapEntries.filter { $0.delta < -eps } : strong
                return base.sorted { $0.delta < $1.delta }
            }
        }

        let criticGapGroupHigher = criticGapEntriesFiltered(kind: .groupHigher)
        let criticGapGroupLower = criticGapEntriesFiltered(kind: .groupLower)

        let moviesByGenreRaw: [(genre: String, count: Int)] = {
            var counts: [String: Int] = [:]
            for movie in filteredMovies {
                guard let genres = movie.genres else { continue }
                for g in genres {
                    let name = g.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { continue }
                    counts[name, default: 0] += 1
                }
            }
            return counts
                .map { (genre: $0.key, count: $0.value) }
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.genre.localizedCaseInsensitiveCompare($1.genre) == .orderedAscending
                }
        }()

        let actorsByCountRaw: [ActorEntry] = {
            var counts: [Int: (name: String, count: Int)] = [:]
            for movie in filteredMovies {
                guard let cast = movie.cast else { continue }
                for member in cast {
                    let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    if var existing = counts[member.personId] {
                        existing.count += 1
                        counts[member.personId] = existing
                    } else {
                        counts[member.personId] = (name: trimmed, count: 1)
                    }
                }
            }
            return counts
                .map { ActorEntry(personId: $0.key, name: $0.value.name, count: $0.value.count) }
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        }()

        let moviesByLocation: [(location: String, count: Int)] = {
            var counts: [String: Int] = [:]
            for movie in filteredMovies {
                let loc = normalizedLocation(for: movie)
                counts[loc, default: 0] += 1
            }
            return counts
                .map { (location: $0.key, count: $0.value) }
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending
                }
        }()

        let suggestionsByUser: [(name: String, count: Int)] = {
            var counts: [String: Int] = [:]
            for movie in filteredMovies {
                guard let raw = movie.suggestedBy else { continue }
                let sugg = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sugg.isEmpty else { continue }
                counts[sugg, default: 0] += 1
            }
            return counts
                .map { (name: $0.key, count: $0.value) }
                .sorted {
                    if $0.count != $1.count { return $0.count > $1.count }
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
        }()

        let tasteDynamics = computeTasteDynamics(
            movies: filteredMovies,
            users: users,
            displayedScore: displayedScore(for:),
            reviewerKey: reviewerKey(for:)
        )

        var userStatsByUserId: [UUID: StatsUserStats] = [:]
        for user in users {
            var movieIds = Set<UUID>()
            var scores: [Double] = []

            let idKey = "id:\(user.id.uuidString.lowercased())"
            let nameKey = "name:\(user.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"

            for movie in filteredMovies {
                let userRatings = movie.ratings.filter { r in
                    let k = reviewerKey(for: r)
                    return k == idKey || k == nameKey
                }
                if !userRatings.isEmpty {
                    movieIds.insert(movie.id)
                    scores.append(contentsOf: userRatings.compactMap { displayedScore(for: $0) })
                }
            }

            let ratingsCount = scores.count
            let averageRating: Double?
            if scores.isEmpty {
                averageRating = nil
            } else {
                averageRating = scores.reduce(0, +) / Double(scores.count)
            }

            userStatsByUserId[user.id] = StatsUserStats(
                movieCount: movieIds.count,
                ratingsCount: ratingsCount,
                averageRating: averageRating
            )
        }

        return StatsSnapshot(
            moviesForCurrentTimeRange: moviesForCurrentTimeRange,
            filteredMovies: filteredMovies,
            availableLocations: availableLocations,
            totalRatingsCount: totalRatingsCount,
            activeReviewersCount: activeReviewersCount,
            ratedMoviesCount: ratedMoviesCount,
            ratingCoveragePercentText: ratingCoveragePercentText,
            memberKeysSet: memberKeysSet,
            activeReviewerKeysSet: activeReviewerKeysSet,
            unratedMoviesCount: unratedMoviesCount,
            moviesRatedByAllActiveMembersCount: moviesRatedByAllActiveMembersCount,
            moviesRatedByAllMembersCount: moviesRatedByAllMembersCount,
            overallAverageRating: overallAverageRating,
            mostRecentWatchedDate: mostRecentWatchedDate,
            monthTrends: monthTrends,
            moviesPerMonth: moviesPerMonth,
            topRatedHighlights: topRatedHighlights,
            controversialHighlights: controversialHighlights,
            criticGapEntries: criticGapEntries,
            criticGapGroupHigher: criticGapGroupHigher,
            criticGapGroupLower: criticGapGroupLower,
            moviesByGenreRaw: moviesByGenreRaw,
            actorsByCountRaw: actorsByCountRaw,
            moviesByLocation: moviesByLocation,
            suggestionsByUser: suggestionsByUser,
            tasteTwins: tasteDynamics.tasteTwins,
            frictionPair: tasteDynamics.frictionPair,
            strictestReviewer: tasteDynamics.strictestReviewer,
            mostGenerousReviewer: tasteDynamics.mostGenerousReviewer,
            hotTakeReviewer: tasteDynamics.hotTakeReviewer,
            userStatsByUserId: userStatsByUserId
        )
    }
}
