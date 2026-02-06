//
//  MovieSearchView+Recommendations.swift
//  filmfreaks
//

internal import SwiftUI

extension MovieSearchView {

    // MARK: - Recommendations

    func loadRecommendationsIfNeeded(force: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return }
        // Wenn das Suchfeld gerade Fokus hat, sollen „Inspirationen“ nicht auftauchen (und müssen auch nicht geladen werden).
        guard !isSearchFieldFocused else { return }
        // Nur laden, wenn wir wirklich im Idle-State sind.
        guard results.isEmpty && !isLoading else { return }
        guard !isLoadingRecommendations else { return }

        if !force, let cached = RecommendationsCacheManager.load(maxAge: recommendationsCacheMaxAge) {
            await MainActor.run {
                self.recommendations = cached.results
                self.recommendationsSeedTitle = cached.seedTitle
                self.recommendationsLastUpdated = cached.timestamp
                self.recommendationsError = nil
            }
            return
        }

        let seeds = recommendationSeedMovies()
        if seeds.isEmpty && !recommendationsFallbackToPopularIfNoSeeds {
            await MainActor.run {
                self.recommendations = []
                self.recommendationsSeedTitle = nil
                self.recommendationsLastUpdated = nil
                self.recommendationsError = "Noch keine geeigneten „Gesehen“-Filme mit TMDb-ID gefunden."
            }
            RecommendationsCacheManager.clear()
            return
        }

        await MainActor.run {
            self.isLoadingRecommendations = true
            self.recommendationsError = nil
        }

        do {
            let existingKeys = localWatchedKeys.union(localBacklogKeys)

            var aggregated: [TMDbMovieResult] = []
            let seedTitle: String? = seeds.first?.title

            if seeds.isEmpty {
                // ✅ Fallback: wenn noch keine Seeds da sind, zeig „Beliebt auf TMDb“
                let response = try await TMDbAPI.shared.fetchPopularMovies(page: 1)
                aggregated = response.results
            } else {
                // bewusst klein halten: 3 Seeds = 3 Requests, meist reicht das
                for seed in seeds.prefix(3) {
                    guard let tmdbId = seed.tmdbId else { continue }
                    let response = try await TMDbAPI.shared.fetchMovieRecommendations(id: tmdbId, page: 1)
                    aggregated.append(contentsOf: response.results)
                    if aggregated.count >= 80 { break }
                }
            }

            // Fallback: wenn recommendations leer sind, probieren wir „similar“ für den ersten Seed
            if aggregated.isEmpty, let firstId = seeds.first?.tmdbId {
                let response = try await TMDbAPI.shared.fetchMovieSimilar(id: firstId, page: 1)
                aggregated = response.results
            }

            // Dedupe + nicht schon in Listen + limit
            var seen = Set<Int>()
            var filtered: [TMDbMovieResult] = []

            for r in aggregated {
                if seen.contains(r.id) { continue }
                seen.insert(r.id)

                let key = MovieSearchMapper.key(for: r)
                if existingKeys.contains(key) { continue }

                filtered.append(r)
                if filtered.count >= 20 { break }
            }

            await MainActor.run {
                self.recommendations = filtered
                self.recommendationsSeedTitle = seedTitle
                self.recommendationsLastUpdated = Date()
                self.isLoadingRecommendations = false
            }

            RecommendationsCacheManager.save(seedTitle: seedTitle, results: filtered)

        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.recommendationsError = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoadingRecommendations = false
            }
        } catch {
            await MainActor.run {
                self.recommendationsError = "Konnte keine Empfehlungen laden. Bitte später nochmal versuchen."
                self.isLoadingRecommendations = false
            }
        }
    }

    private func recommendationSeedMovies() -> [Movie] {
        let candidates = existingWatched.filter { $0.tmdbId != nil }
        guard !candidates.isEmpty else { return [] }

        // 1) „Zuletzt gesehen“
        let recentSorted = candidates.sorted {
            ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast)
        }
        let recentSeeds = Array(recentSorted.prefix(3))

        // 2) „Höchste eigene Bewertung“ (best effort; siehe ownRatingBestEffort)
        let ratedSeeds: [Movie] = candidates
            .compactMap { movie -> (Movie, Double)? in
                guard let r = ownRatingBestEffort(for: movie) else { return nil }
                return (movie, r)
            }
            .sorted { a, b in
                if a.1 == b.1 {
                    // stabil: bei gleicher Bewertung zuletzt gesehen zuerst
                    return (a.0.watchedDate ?? .distantPast) > (b.0.watchedDate ?? .distantPast)
                }
                return a.1 > b.1
            }
            .map { $0.0 }

        // Mix: abwechselnd recent / rated, dedupe per TMDb-ID (Fallback: title|year)
        var mixed: [Movie] = []
        var seenTMDbIds = Set<Int>()
        var seenKeys = Set<String>()

        func add(_ movie: Movie) {
            if let id = movie.tmdbId {
                if seenTMDbIds.contains(id) { return }
                seenTMDbIds.insert(id)
            } else {
                let k = MovieSearchMapper.key(for: movie)
                if seenKeys.contains(k) { return }
                seenKeys.insert(k)
            }
            mixed.append(movie)
        }

        let maxCount = max(recentSeeds.count, ratedSeeds.count)
        for i in 0..<maxCount {
            if i < recentSeeds.count { add(recentSeeds[i]) }
            if i < ratedSeeds.count { add(ratedSeeds[i]) }
            if mixed.count >= 5 { break }
        }

        // Falls noch nicht genug: mit „recent“ auffüllen (stabil, predictable)
        if mixed.count < 5 {
            for m in recentSorted {
                add(m)
                if mixed.count >= 5 { break }
            }
        }

        // 5 Seeds reichen; wir nehmen später sowieso nur 3 Requests
        return Array(mixed.prefix(5))
    }

    /// Best-effort Ermittlung der „eigenen“ Bewertung, ohne deine Model-Types hart zu referenzieren.
    /// - 1) Versucht direkte Felder am `Movie` (z.B. myRating/ownRating/personalRating/userRating…)
    /// - 2) Fällt auf `ratings` zurück (sucht nach Own-Flag; sonst nimmt es das Maximum, besser als nix)
    private func ownRatingBestEffort(for movie: Movie) -> Double? {
        // 1) Direkt am Movie
        let directKeys = [
            "myRating", "ownRating", "personalRating", "userRating",
            "personalScore", "myScore"
        ]
        for key in directKeys {
            if let raw = reflectedValue(named: key, in: movie),
               let num = extractNumeric(raw) {
                return num
            }
        }

        // 2) ratings-Array am Movie
        guard let ratingsRaw = reflectedValue(named: "ratings", in: movie) else { return nil }
        guard let arr = ratingsRaw as? [Any] else { return nil }

        let ownFlags = ["isOwn", "isMine", "isMe", "isCurrentUser", "isUser", "isSelf"]
        let valueKeys = ["rating", "score", "value", "points"]

        // 2a) Own-Flag suchen
        for item in arr {
            for flag in ownFlags {
                if let fv = reflectedValue(named: flag, in: item),
                   let b = fv as? Bool,
                   b == true {
                    for vk in valueKeys {
                        if let vv = reflectedValue(named: vk, in: item),
                           let num = extractNumeric(vv) {
                            return num
                        }
                    }
                }
            }
        }

        // 2b) Kein Own-Flag gefunden → nimm das höchste, das wir finden (Fallback)
        var best: Double?
        for item in arr {
            for vk in valueKeys {
                if let vv = reflectedValue(named: vk, in: item),
                   let num = extractNumeric(vv) {
                    best = max(best ?? num, num)
                }
            }
        }
        return best
    }

    private func reflectedValue(named name: String, in any: Any) -> Any? {
        for child in Mirror(reflecting: any).children {
            if child.label == name { return child.value }
        }
        return nil
    }

    private func extractNumeric(_ any: Any) -> Double? {
        switch any {
        case let d as Double: return d
        case let f as Float: return Double(f)
        case let i as Int: return Double(i)
        case let i as Int16: return Double(i)
        case let i as Int32: return Double(i)
        case let i as Int64: return Double(i)
        case let u as UInt: return Double(u)
        case let u as UInt16: return Double(u)
        case let u as UInt32: return Double(u)
        case let u as UInt64: return Double(u)
        case let s as String:
            // „7,5“ → 7.5
            return Double(s.replacingOccurrences(of: ",", with: "."))
        default:
            return nil
        }
    }
}
