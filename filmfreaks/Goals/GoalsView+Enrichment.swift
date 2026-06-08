//
//  GoalsView+Enrichment.swift
//  filmfreaks
//
//  Optional metadata enrichment for goal matching (directors/genres/keywords).
//

internal import SwiftUI

extension GoalsView {

    // MARK: - Metadata Enrichment (nur wenn nötig)

    private func needsDetailsEnrichment(for goalTypes: Set<ViewingCustomGoalType>) -> [Movie] {
        return moviesInSelectedYear.filter { m in
            guard m.tmdbId != nil else { return false }
            if goalTypes.contains(.director) {
                if (m.directors ?? []).isEmpty { return true }
            }
            if goalTypes.contains(.genre) {
                if (m.genreIds ?? []).isEmpty && (m.genres ?? []).isEmpty { return true }
            }
            if goalTypes.contains(.keyword) {
                if (m.keywordIds ?? []).isEmpty && (m.keywords ?? []).isEmpty { return true }
            }
            return false
        }
    }

    func triggerMetadataEnrichmentIfNeeded() async {
        if isEnrichingMetadata { return }

        let typesNeeded = Set(customGoalsForSelectedYear.map { $0.type })
            .intersection([.director, .genre, .keyword])

        guard !typesNeeded.isEmpty else { return }

        let targets = needsDetailsEnrichment(for: typesNeeded)
        guard !targets.isEmpty else { return }

        isEnrichingMetadata = true
        defer { isEnrichingMetadata = false }

        // Wir holen pro Film einmal "große" Details (credits+keywords+genres),
        // weil wir damit alle Goal-Typen in einem Request abdecken.
        struct Update {
            let movieId: UUID
            let patch: MovieMetadataLoadedMoviePatch
            let popularitySeeds: [PersonPopularityStore.Seed]
        }

        var updates: [Update] = []
        updates.reserveCapacity(targets.count)

        await withTaskGroup(of: Update?.self) { group in
            for m in targets {
                guard let tmdbId = m.tmdbId else { continue }
                let movieId = m.id

                group.addTask {
                    do {
                        let details = try await TMDbAPI.shared.fetchMovieDetails(id: tmdbId)

                        let seeds: [PersonPopularityStore.Seed] = {
                            guard let credits = details.credits else { return [] }
                            var out: [PersonPopularityStore.Seed] = []
                            out.reserveCapacity(credits.cast.count + credits.crew.count)

                            for c in credits.cast {
                                guard let pop = c.popularity else { continue }
                                out.append(PersonPopularityStore.Seed(personId: c.id, popularity: pop))
                            }
                            for c in credits.crew {
                                guard let pop = c.popularity else { continue }
                                out.append(PersonPopularityStore.Seed(personId: c.id, popularity: pop))
                            }
                            return out
                        }()

                        return Update(
                            movieId: movieId,
                            patch: MovieMetadataLoadedMoviePatch(details: details),
                            popularitySeeds: seeds
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await u in group {
                if let u { updates.append(u) }
            }
        }

        guard !updates.isEmpty else { return }

        // ✅ Seed Popularity aus Details-Credits (ohne /person Calls)
        let allSeeds: [PersonPopularityStore.Seed] = updates.flatMap { $0.popularitySeeds }
        PersonPopularityStore.shared.ingestPopularity(seeds: allSeeds)

        // Apply in one shot (damit Persistenz/Cloud nicht pro Movie triggert)
        var updatedList = movieStore.movies
        var didChange = false

        for u in updates {
            guard let idx = updatedList.firstIndex(where: { $0.id == u.movieId }) else { continue }

            if typesNeeded.contains(.genre) {
                if let names = u.patch.genres, !names.isEmpty {
                    if updatedList[idx].genres != names {
                        updatedList[idx].genres = names
                        didChange = true
                    }
                }
                if let ids = u.patch.genreIds, !ids.isEmpty {
                    if updatedList[idx].genreIds != ids {
                        updatedList[idx].genreIds = ids
                        didChange = true
                    }
                }
            }

            if typesNeeded.contains(.keyword) {
                if let names = u.patch.keywords, !names.isEmpty {
                    if updatedList[idx].keywords != names {
                        updatedList[idx].keywords = names
                        didChange = true
                    }
                }
                if let ids = u.patch.keywordIds, !ids.isEmpty {
                    if updatedList[idx].keywordIds != ids {
                        updatedList[idx].keywordIds = ids
                        didChange = true
                    }
                }
            }

            if typesNeeded.contains(.director) {
                if let directors = u.patch.directors, !directors.isEmpty {
                    if updatedList[idx].directors != directors {
                        updatedList[idx].directors = directors
                        didChange = true
                    }
                }
            }
        }

        if didChange {
            await MainActor.run {
                movieStore.movies = updatedList
            }
        }
    }
}
