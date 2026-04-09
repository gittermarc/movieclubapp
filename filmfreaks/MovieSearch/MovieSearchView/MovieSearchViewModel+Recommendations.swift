import Foundation

extension MovieSearchViewModel {

    func loadRecommendationsIfNeeded(
        query: String,
        isSearchFieldFocused: Bool,
        localWatchedKeys: Set<String>,
        localBacklogKeys: Set<String>,
        force: Bool = false
    ) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return }
        guard !isSearchFieldFocused else { return }
        guard results.isEmpty && !isLoading else { return }
        guard !isLoadingRecommendations else { return }

        if !force,
           let cached = dependencies.loadRecommendationsCache(recommendationsCacheMaxAge) {
            recommendations = cached.results
            recommendationsSeedTitle = cached.seedTitle
            recommendationsLastUpdated = cached.timestamp
            recommendationsError = nil
            return
        }

        let seeds = recommendationSeedMovies()
        if seeds.isEmpty && !recommendationsFallbackToPopularIfNoSeeds {
            recommendations = []
            recommendationsSeedTitle = nil
            recommendationsLastUpdated = nil
            recommendationsError = "Noch keine geeigneten „Gesehen“-Filme mit TMDb-ID gefunden."
            dependencies.clearRecommendationsCache()
            return
        }

        isLoadingRecommendations = true
        recommendationsError = nil

        do {
            let existingKeys = localWatchedKeys.union(localBacklogKeys)

            var aggregated: [TMDbMovieResult] = []
            let seedTitle = seeds.first?.title

            if seeds.isEmpty {
                let response = try await dependencies.fetchPopularMovies(1)
                aggregated = response.results
            } else {
                for seed in seeds.prefix(3) {
                    guard let tmdbId = seed.tmdbId else { continue }
                    let response = try await dependencies.fetchMovieRecommendations(tmdbId, 1)
                    aggregated.append(contentsOf: response.results)
                    if aggregated.count >= 80 { break }
                }
            }

            if aggregated.isEmpty,
               let firstId = seeds.first?.tmdbId {
                let response = try await dependencies.fetchMovieSimilar(firstId, 1)
                aggregated = response.results
            }

            var seen = Set<Int>()
            var filtered: [TMDbMovieResult] = []

            for result in aggregated {
                if seen.contains(result.id) { continue }
                seen.insert(result.id)

                let key = MovieSearchMapper.key(for: result)
                if existingKeys.contains(key) { continue }

                filtered.append(result)
                if filtered.count >= 20 { break }
            }

            recommendations = filtered
            recommendationsSeedTitle = seedTitle
            recommendationsLastUpdated = dependencies.now()
            isLoadingRecommendations = false

            dependencies.saveRecommendationsCache(seedTitle, filtered)
        } catch TMDbError.missingAPIKey {
            recommendationsError = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
            isLoadingRecommendations = false
        } catch {
            recommendationsError = "Konnte keine Empfehlungen laden. Bitte später nochmal versuchen."
            isLoadingRecommendations = false
        }
    }

    private func recommendationSeedMovies() -> [Movie] {
        let candidates = existingWatched.filter { $0.tmdbId != nil }
        guard !candidates.isEmpty else { return [] }

        let recentSorted = candidates.sorted {
            ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast)
        }
        let recentSeeds = Array(recentSorted.prefix(3))

        let ratedSeeds: [Movie] = candidates
            .compactMap { movie -> (Movie, Double)? in
                guard let rating = ownRatingBestEffort(for: movie) else { return nil }
                return (movie, rating)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return (lhs.0.watchedDate ?? .distantPast) > (rhs.0.watchedDate ?? .distantPast)
                }
                return lhs.1 > rhs.1
            }
            .map { $0.0 }

        var mixed: [Movie] = []
        var seenTMDbIds = Set<Int>()
        var seenKeys = Set<String>()

        func add(_ movie: Movie) {
            if let id = movie.tmdbId {
                if seenTMDbIds.contains(id) { return }
                seenTMDbIds.insert(id)
            } else {
                let key = MovieSearchMapper.key(for: movie)
                if seenKeys.contains(key) { return }
                seenKeys.insert(key)
            }
            mixed.append(movie)
        }

        let maxCount = max(recentSeeds.count, ratedSeeds.count)
        for index in 0..<maxCount {
            if index < recentSeeds.count { add(recentSeeds[index]) }
            if index < ratedSeeds.count { add(ratedSeeds[index]) }
            if mixed.count >= 5 { break }
        }

        if mixed.count < 5 {
            for movie in recentSorted {
                add(movie)
                if mixed.count >= 5 { break }
            }
        }

        return Array(mixed.prefix(5))
    }

    private func ownRatingBestEffort(for movie: Movie) -> Double? {
        let directKeys = [
            "myRating", "ownRating", "personalRating", "userRating",
            "personalScore", "myScore"
        ]
        for key in directKeys {
            if let raw = reflectedValue(named: key, in: movie),
               let number = extractNumeric(raw) {
                return number
            }
        }

        guard let ratingsRaw = reflectedValue(named: "ratings", in: movie) else { return nil }
        guard let ratings = ratingsRaw as? [Any] else { return nil }

        let ownFlags = ["isOwn", "isMine", "isMe", "isCurrentUser", "isUser", "isSelf"]
        let valueKeys = ["rating", "score", "value", "points"]

        for item in ratings {
            for flag in ownFlags {
                if let flagValue = reflectedValue(named: flag, in: item),
                   let isOwn = flagValue as? Bool,
                   isOwn {
                    for valueKey in valueKeys {
                        if let value = reflectedValue(named: valueKey, in: item),
                           let number = extractNumeric(value) {
                            return number
                        }
                    }
                }
            }
        }

        var best: Double?
        for item in ratings {
            for valueKey in valueKeys {
                if let value = reflectedValue(named: valueKey, in: item),
                   let number = extractNumeric(value) {
                    best = max(best ?? number, number)
                }
            }
        }
        return best
    }

    private func reflectedValue(named name: String, in value: Any) -> Any? {
        for child in Mirror(reflecting: value).children {
            if child.label == name { return child.value }
        }
        return nil
    }

    private func extractNumeric(_ value: Any) -> Double? {
        switch value {
        case let double as Double: return double
        case let float as Float: return Double(float)
        case let int as Int: return Double(int)
        case let int as Int16: return Double(int)
        case let int as Int32: return Double(int)
        case let int as Int64: return Double(int)
        case let uint as UInt: return Double(uint)
        case let uint as UInt16: return Double(uint)
        case let uint as UInt32: return Double(uint)
        case let uint as UInt64: return Double(uint)
        case let string as String:
            return Double(string.replacingOccurrences(of: ",", with: "."))
        default:
            return nil
        }
    }
}
