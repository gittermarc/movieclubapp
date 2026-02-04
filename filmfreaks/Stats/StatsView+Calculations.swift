//
//  StatsView+Calculations.swift
//  filmfreaks
//
//  Data + aggregation helpers for StatsView.
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

    // MARK: - Basis & Filter

    var moviesForCurrentTimeRange: [Movie] {
        let calendar = Calendar.current
        let today = Date()

        return movieStore.movies.compactMap { movie in
            guard let date = movie.watchedDate else { return nil }

            switch selectedRange {
            case .all:
                return movie
            case .thisYear:
                if calendar.isDate(date, equalTo: today, toGranularity: .year) { return movie }
            case .last30:
                if let from = calendar.date(byAdding: .day, value: -30, to: today),
                   date >= from { return movie }
            case .last90:
                if let from = calendar.date(byAdding: .day, value: -90, to: today),
                   date >= from { return movie }
            }
            return nil
        }
    }

    var filteredMovies: [Movie] {
        guard let loc = selectedLocationFilter else {
            return moviesForCurrentTimeRange
        }
        return moviesForCurrentTimeRange.filter { normalizedLocation(for: $0) == loc }
    }

    var availableLocations: [String] {
        let locations = moviesForCurrentTimeRange.map { normalizedLocation(for: $0) }
        let unique = Set(locations)
        return Array(unique).sorted()
    }

    func normalizedLocation(for movie: Movie) -> String {
        let trimmed = movie.watchedLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Ohne Angabe" : trimmed
    }
    // MARK: - KPIs

    var totalRatingsCount: Int {
        filteredMovies.reduce(0) { $0 + $1.ratings.count }
    }

    /// Unique reviewers within the current filtered set.
    /// Uses stable reviewerId where possible; falls back to matching by display name.
    var activeReviewersCount: Int {
        Set(filteredMovies.flatMap { movie in
            movie.ratings.map { reviewerKey(for: $0) }
        }).count
    }

    var ratedMoviesCount: Int {
        filteredMovies.filter { !$0.ratings.isEmpty }.count
    }

    var ratingCoveragePercentText: String {
        guard filteredMovies.count > 0 else { return "0%" }
        let pct = (Double(ratedMoviesCount) / Double(filteredMovies.count)) * 100.0
        return String(format: "%.0f%% bewertet", pct)
    }

    // MARK: - Group Health

    /// Stable key for a rating's reviewer.
    /// Prefers reviewerId; otherwise tries to match by name against current members;
    /// finally falls back to a canonical name key.
    private func reviewerKey(for rating: Rating) -> String {
        if let rid = rating.reviewerId {
            return "id:\(rid.uuidString.lowercased())"
        }
        let canon = rating.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !canon.isEmpty, let match = userStore.users.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == canon
        }) {
            return "id:\(match.id.uuidString.lowercased())"
        }
        return "name:\(canon)"
    }


    /// Members as stable keys (id + name fallback), to support both new and legacy ratings.
    var memberKeysSet: Set<String> {
        var set: Set<String> = []
        for u in userStore.users {
            set.insert("id:\(u.id.uuidString.lowercased())")
            let nameKey = u.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !nameKey.isEmpty {
                set.insert("name:\(nameKey)")
            }
        }
        return set
    }

    /// Reviewers that have at least one rating in the current filtered set.
    var activeReviewerKeysSet: Set<String> {
        let keys = filteredMovies
            .flatMap { $0.ratings.map { reviewerKey(for: $0) } }
        return Set(keys)
    }

    var unratedMoviesCount: Int {
        max(0, filteredMovies.count - ratedMoviesCount)
    }

    /// Movies rated by all active members (active = has at least one rating in current filtered set).
    var moviesRatedByAllActiveMembersCount: Int {
        let active = activeReviewerKeysSet
        guard !active.isEmpty else { return 0 }

        return filteredMovies.filter { movie in
            let reviewers = Set(movie.ratings.map { reviewerKey(for: $0) })
            return active.isSubset(of: reviewers)
        }.count
    }

    /// Movies rated by all members (from member list).
    var moviesRatedByAllMembersCount: Int {
        let members = memberKeysSet
        guard !members.isEmpty else { return 0 }

        return filteredMovies.filter { movie in
            let reviewers = Set(movie.ratings.map { reviewerKey(for: $0) })
            return members.isSubset(of: reviewers)
        }.count
    }

    // MARK: - Aggregationen

    var overallAverageRating: Double? {
        let allScores = filteredMovies.flatMap { movie in
            movie.ratings.compactMap { displayedScore(for: $0) }
        }
        guard !allScores.isEmpty else { return nil }
        let total = allScores.reduce(0, +)
        return total / Double(allScores.count)
    }

    var mostRecentWatchedDate: Date? {
        filteredMovies.compactMap { $0.watchedDate }.max()
    }

    var monthTrends: [StatsMonthTrend] {
        let calendar = Calendar.current
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
    }

    /// Für Chips (aktuellste Monate zuerst)
    var moviesPerMonth: [(date: Date, count: Int)] {
        monthTrends
            .map { (date: $0.monthStart, count: $0.movieCount) }
            .sorted { $0.date > $1.date }
    }

    var topRatedHighlights: [MovieHighlight] {
        let base = filteredMovies.compactMap { movie -> MovieHighlight? in
            guard let avg = movie.groupAverage(for: displaySettings.ratingDisplayMode) else { return nil }
            return MovieHighlight(movie: movie, value: avg)
        }

        return base
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0 }
    }

    var controversialHighlights: [MovieHighlight] {
        let base = filteredMovies.compactMap { movie -> MovieHighlight? in
            let values = movie.ratings.compactMap { displayedScore(for: $0) }
            guard values.count >= 2 else { return nil }
            let sd = standardDeviation(values)
            return MovieHighlight(movie: movie, value: sd)
        }

        return base
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Kritik vs TMDB

    var criticGapEntries: [CriticGapEntry] {
        filteredMovies.compactMap { movie -> CriticGapEntry? in
            guard let groupAvg = movie.groupAverage(for: displaySettings.ratingDisplayMode) else { return nil }
            guard let tmdb = movie.tmdbRating else { return nil }

            let delta = groupAvg - tmdb
            return CriticGapEntry(movie: movie, groupAverage: groupAvg, tmdbAverage: tmdb, delta: delta)
        }
    }

    var criticGapGroupHigher: [CriticGapEntry] {
        criticGapEntriesFiltered(kind: .groupHigher)
    }

    var criticGapGroupLower: [CriticGapEntry] {
        criticGapEntriesFiltered(kind: .groupLower)
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
            return base.sorted { $0.delta < $1.delta } // negative zuerst (stärkste Abweichung)
        }
    }

    // MARK: - Genres / Cast / Orte / Vorschläge

    var moviesByGenreRaw: [(genre: String, count: Int)] {
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
    }

    var genresDisplaySource: [(genre: String, count: Int)] {
        genreDisplayOrder.isEmpty ? moviesByGenreRaw : genreDisplayOrder
    }

    /// ✅ Rohdaten: Häufigkeit pro Darsteller – personId-basiert
    var actorsByCountRaw: [ActorEntry] {
        var counts: [Int: (name: String, count: Int)] = [:]

        for movie in filteredMovies {
            guard let cast = movie.cast else { continue }
            for member in cast {
                let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                if var existing = counts[member.personId] {
                    existing.count += 1
                    // Namen behalten wir stabil (erster gewinnt)
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
    }

    var actorsDisplaySource: [ActorEntry] {
        actorDisplayOrder.isEmpty ? actorsByCountRaw : actorDisplayOrder
    }

    /// Sortierung: Häufigkeit, dann Popularität (per personId), dann Name
    func computeActorsSortedUsingPopularity() -> [ActorEntry] {
        let raw = actorsByCountRaw
        return raw.sorted { a, b in
            if a.count != b.count { return a.count > b.count }

            let popA = popularityStore.popularityValue(for: a.personId)
            let popB = popularityStore.popularityValue(for: b.personId)
            if popA != popB { return popA > popB }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    var moviesByLocation: [(location: String, count: Int)] {
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
    }

    var suggestionsByUser: [(name: String, count: Int)] {
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
    }

    func statsForUser(_ user: User) -> (movieCount: Int, ratingsCount: Int, averageRating: Double?) {
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

        guard !scores.isEmpty else { return (movieIds.count, 0, nil) }

        let total = scores.reduce(0, +)
        let avg = total / Double(scores.count)
        return (movieIds.count, scores.count, avg)
    }

    // MARK: - Intern

    /// Einzelscore pro User-Bewertung, abhängig vom ausgewählten Modus.
    /// - ratingAverage: Kriterien-Ø (wie bisher)
    /// - fazitAverage: Fazit (1–10), mit Fallback auf Kriterien für Legacy
    private func displayedScore(for rating: Rating) -> Double? {
        switch displaySettings.ratingDisplayMode {
        case .ratingAverage:
            return rating.averageScoreNormalizedTo10
        case .fazitAverage:
            if let f = rating.fazitScore {
                return Double(f)
            }
            // Fallback nur, wenn es wenigstens irgendeine sinnvolle Kriterien-Wertung gibt.
            let v = rating.averageScoreNormalizedTo10
            return v > 0 ? v : nil
        }
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}
