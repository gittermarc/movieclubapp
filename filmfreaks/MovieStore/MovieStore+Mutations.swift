//
//  MovieStore+Mutations.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

import Foundation

internal extension MovieStore {

    // MARK: - Ratings (Version B: MovieRating Records)

    /// Stable reviewer identity key used to merge ratings.
    func reviewerKey(_ r: Rating) -> String {
        if let rid = r.reviewerId { return rid.uuidString.lowercased() }
        if let gid = currentGroupId, !gid.isEmpty {
            return StableID.deterministicUUID(forName: r.reviewerName, groupId: gid).uuidString.lowercased()
        }
        return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Ensures reviewerId is present for legacy ratings (best-effort).
    func normalizedRating(_ r: Rating) -> Rating {
        var copy = r
        if copy.reviewerId == nil, let gid = currentGroupId, !gid.isEmpty {
            copy.reviewerId = StableID.deterministicUUID(forName: copy.reviewerName, groupId: gid)
        }
        return copy
    }

    /// Merged Ratings: `incoming` überschreibt bestehende Ratings pro Reviewer (stabile IDs).
    func mergeRatings(existing: [Rating], incoming: [Rating]) -> [Rating] {
        var out = existing.map(normalizedRating)
        for raw in incoming {
            let r = normalizedRating(raw)
            let key = reviewerKey(r)
            if let idx = out.firstIndex(where: { reviewerKey($0) == key }) {
                out[idx] = r
            } else {
                out.append(r)
            }
        }
        return out
    }

    /// Speichert/aktualisiert die Bewertung des aktuellen Users für einen Film.
    /// - Wichtig: Ratings werden in CloudKit als eigene Records gespeichert (MovieRating).
    func upsertRating(for movieId: UUID, rating: Rating) async -> Bool {
        var stampedRating = rating
        stampedRating.updatedAt = Date()

        // 1) Lokal in die UI-Models mergen (für sofortiges Feedback + Offline)
        if let idx = movies.firstIndex(where: { $0.id == movieId }) {
            var m = movies[idx]
            m.ratings = mergeRatings(existing: m.ratings, incoming: [stampedRating])
            movies[idx] = m
        }
        if let idx = backlogMovies.firstIndex(where: { $0.id == movieId }) {
            var m = backlogMovies[idx]
            m.ratings = mergeRatings(existing: m.ratings, incoming: [stampedRating])
            backlogMovies[idx] = m
        }

        // 2) Cloud speichern
        guard let cloudRatingStore else { return true }
        do {
            try await cloudRatingStore.saveRating(stampedRating, movieId: movieId, groupId: currentGroupId)
            return true
        } catch {
            print("CloudKit rating save error: \(error)")
            return false
        }
    }

    /// Löscht eine Bewertung für einen Film anhand der stabilen Reviewer-ID.
    func deleteRating(for movieId: UUID, reviewerId: UUID) async -> Bool {
        // Lokal entfernen
        func remove(from list: inout [Movie]) {
            guard let idx = list.firstIndex(where: { $0.id == movieId }) else { return }
            var m = list[idx]
            m.ratings.removeAll { r in
                if let rid = r.reviewerId { return rid == reviewerId }
                // Legacy fallback
                if let gid = currentGroupId, !gid.isEmpty {
                    let legacy = StableID.deterministicUUID(forName: r.reviewerName, groupId: gid)
                    return legacy == reviewerId
                }
                return false
            }
            list[idx] = m
        }
        remove(from: &movies)
        remove(from: &backlogMovies)

        guard let cloudRatingStore else { return true }
        do {
            try await cloudRatingStore.deleteRating(movieId: movieId, groupId: currentGroupId, reviewerId: reviewerId)
            return true
        } catch {
            print("CloudKit rating delete error: \(error)")
            return false
        }
    }

    /// Legacy Convenience: Löscht per Name (best-effort) – wird auf reviewerId gemappt, wenn möglich.
    func deleteRating(for movieId: UUID, reviewerName: String) async -> Bool {
        let trimmed = reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        if let gid = currentGroupId, !gid.isEmpty {
            let rid = StableID.deterministicUUID(forName: trimmed, groupId: gid)
            return await deleteRating(for: movieId, reviewerId: rid)
        }

        // Fallback (no-group): remove by name only locally
        func remove(from list: inout [Movie]) {
            guard let idx = list.firstIndex(where: { $0.id == movieId }) else { return }
            var m = list[idx]
            m.ratings.removeAll { $0.reviewerName.lowercased() == trimmed.lowercased() }
            list[idx] = m
        }
        remove(from: &movies)
        remove(from: &backlogMovies)
        return true
    }

    // MARK: - ✅ CAST Migration (Legacy → TMDb Person IDs)

    func migrateCastDataIfNeeded() async {
        if isMigratingCast { return }
        isMigratingCast = true
        defer { isMigratingCast = false }

        // Snapshot
        var watched = self.movies
        var backlog = self.backlogMovies

        func needsMigration(_ movie: Movie) -> Bool {
            guard let cast = movie.cast, !cast.isEmpty else { return movie.tmdbId != nil }
            // Legacy IDs sind negativ (aus dem Decoder)
            return cast.contains(where: { $0.personId < 0 }) && movie.tmdbId != nil
        }

        let watchedTargets = watched.filter(needsMigration)
        let backlogTargets = backlog.filter(needsMigration)

        if watchedTargets.isEmpty && backlogTargets.isEmpty { return }

        struct Update {
            let movieId: UUID
            let isBacklog: Bool
            let newCast: [CastMember]
        }

        var updates: [Update] = []
        updates.reserveCapacity(watchedTargets.count + backlogTargets.count)

        // Wir ziehen IDs + tmdbId raus, damit wir sauber parallelisieren können
        let watchedJobs: [(UUID, Int)] = watchedTargets.compactMap { m in
            guard let tmdb = m.tmdbId else { return nil }
            return (m.id, tmdb)
        }
        let backlogJobs: [(UUID, Int)] = backlogTargets.compactMap { m in
            guard let tmdb = m.tmdbId else { return nil }
            return (m.id, tmdb)
        }

        // Parallel, aber mit überschaubarer Last
        await withTaskGroup(of: Update?.self) { group in
            for (movieId, tmdbId) in watchedJobs {
                group.addTask {
                    do {
                        let credits = try await TMDbAPI.shared.fetchMovieCredits(id: tmdbId)
                        let cast = credits.cast
                            .prefix(30)
                            .map { CastMember(personId: $0.id, name: $0.name) }
                        return Update(movieId: movieId, isBacklog: false, newCast: cast)
                    } catch {
                        return nil
                    }
                }
            }

            for (movieId, tmdbId) in backlogJobs {
                group.addTask {
                    do {
                        let credits = try await TMDbAPI.shared.fetchMovieCredits(id: tmdbId)
                        let cast = credits.cast
                            .prefix(30)
                            .map { CastMember(personId: $0.id, name: $0.name) }
                        return Update(movieId: movieId, isBacklog: true, newCast: cast)
                    } catch {
                        return nil
                    }
                }
            }

            for await u in group {
                if let u { updates.append(u) }
            }
        }

        if updates.isEmpty { return }

        // Apply in local arrays
        for u in updates {
            if u.isBacklog {
                if let idx = backlog.firstIndex(where: { $0.id == u.movieId }) {
                    backlog[idx].cast = u.newCast
                }
            } else {
                if let idx = watched.firstIndex(where: { $0.id == u.movieId }) {
                    watched[idx].cast = u.newCast
                }
            }
        }

        // ✅ Set nur einmal (spart Persistenz-/Cloud-Overhead)
        self.movies = watched
        self.backlogMovies = backlog
    }
}
