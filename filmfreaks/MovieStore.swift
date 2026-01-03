//
//  MovieStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
internal import SwiftUI
import Combine

struct GroupInfo: Identifiable, Codable, Equatable {
    var id: String
    var name: String?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "Gruppe \(id.prefix(6))"
    }
}

@MainActor
class MovieStore: ObservableObject {

    @Published var movies: [Movie] = [] {
        didSet {
            if isApplyingCloudUpdate { return }

            if let oldData = try? JSONEncoder().encode(oldValue),
               let newData = try? JSONEncoder().encode(movies),
               oldData == newData {
                return
            }

            PersistenceManager.shared.saveMovies(movies)

            if cloudStore != nil {
                let oldSnapshot = oldValue
                Task {
                    await self.syncChanges(newList: movies, oldList: oldSnapshot, isBacklog: false)
                }
            }
        }
    }

    @Published var backlogMovies: [Movie] = [] {
        didSet {
            if isApplyingCloudUpdate { return }

            if let oldData = try? JSONEncoder().encode(oldValue),
               let newData = try? JSONEncoder().encode(backlogMovies),
               oldData == newData {
                return
            }

            PersistenceManager.shared.saveBacklogMovies(backlogMovies)

            if cloudStore != nil {
                let oldSnapshot = oldValue
                Task {
                    await self.syncChanges(newList: backlogMovies, oldList: oldSnapshot, isBacklog: true)
                }
            }
        }
    }

    @Published var isSyncing: Bool = false

    @Published var currentGroupId: String? {
        didSet {
            UserDefaults.standard.set(currentGroupId, forKey: "CurrentGroupId")
            addOrUpdateCurrentGroupInKnownGroups()
        }
    }

    @Published var currentGroupName: String? {
        didSet {
            UserDefaults.standard.set(currentGroupName, forKey: "CurrentGroupName")
            addOrUpdateCurrentGroupInKnownGroups()
        }
    }

    @Published var knownGroups: [GroupInfo] = [] {
        didSet { saveKnownGroups() }
    }

    private let cloudStore: CloudKitMovieStore?
    private let cloudRatingStore: CloudKitRatingStore?
    private var isApplyingCloudUpdate = false

    // Throttle gegen zu viele Cloud-Fetches
    private var lastRefreshAt: Date?
    private let minRefreshInterval: TimeInterval = 8

    private static let knownGroupsKey = "KnownGroups"

    // ✅ Migration Guard
    private var isMigratingCast = false

    init(useCloud: Bool = true) {
        if useCloud {
            self.cloudStore = CloudKitMovieStore()
            self.cloudRatingStore = CloudKitRatingStore()
        } else {
            self.cloudStore = nil
            self.cloudRatingStore = nil
        }

        self.knownGroups = Self.loadKnownGroups()

        self.currentGroupId = UserDefaults.standard.string(forKey: "CurrentGroupId")
        self.currentGroupName = UserDefaults.standard.string(forKey: "CurrentGroupName")

        addOrUpdateCurrentGroupInKnownGroups()

        let stored = PersistenceManager.shared.loadMovies()
        self.movies = stored

        let backlogStored = PersistenceManager.shared.loadBacklogMovies()
        self.backlogMovies = backlogStored

        // ✅ Automatische Migration (lokale Daten)
        Task { await self.migrateCastDataIfNeeded() }

        if useCloud {
            Task { await self.loadFromCloud() }
        }
    }

    // MARK: - Cloud Laden

    private func loadFromCloud() async {
        guard let cloudStore else { return }

        print("CloudKit: loadFromCloud() START (groupId=\(currentGroupId ?? "nil"))")
        isSyncing = true
        defer {
            isSyncing = false
            print("CloudKit: loadFromCloud() END (groupId=\(currentGroupId ?? "nil"))")
        }

        do {
            let entries = try await cloudStore.fetchMovies(forGroupId: currentGroupId)
            print("CloudKit: fetchMovies(forGroupId:) returned \(entries.count) entries")

            var watched = entries.filter { !$0.isBacklog }.map { $0.movie }
            var backlog = entries.filter { $0.isBacklog }.map { $0.movie }

            // ✅ Ratings sind jetzt eigene CloudKit-Records (MovieRating).
            //    Damit uns lokale/offline Ratings beim Cloud-Reload nicht verloren gehen,
            //    konservieren wir erstmal die aktuell im Speicher vorhandenen Ratings.
            let localRatingsByMovieId: [UUID: [Rating]] = {
                var dict: [UUID: [Rating]] = [:]
                for m in (self.movies + self.backlogMovies) {
                    dict[m.id] = mergeRatings(existing: dict[m.id] ?? [], incoming: m.ratings)
                }
                return dict
            }()

            watched = watched.map { m in
                var copy = m
                copy.ratings = localRatingsByMovieId[copy.id] ?? []
                return copy
            }
            backlog = backlog.map { m in
                var copy = m
                copy.ratings = localRatingsByMovieId[copy.id] ?? []
                return copy
            }

            // ✅ Cloud-Ratings laden und in die Movies mergen
            if let cloudRatingStore = self.cloudRatingStore {
                do {
                    let ids = Array(Set(watched.map(\.id) + backlog.map(\.id)))
                    let cloudRatingsByMovieId = try await cloudRatingStore.fetchRatings(forGroupId: currentGroupId, movieIds: ids)

                    watched = watched.map { m in
                        var copy = m
                        copy.ratings = mergeRatings(existing: copy.ratings, incoming: cloudRatingsByMovieId[copy.id] ?? [])
                        return copy
                    }
                    backlog = backlog.map { m in
                        var copy = m
                        copy.ratings = mergeRatings(existing: copy.ratings, incoming: cloudRatingsByMovieId[copy.id] ?? [])
                        return copy
                    }

                    let total = cloudRatingsByMovieId.values.reduce(0) { $0 + $1.count }
                    print("CloudKit: fetched ratings → \(total) total")
                } catch {
                    print("CloudKit: ratings fetch error: \(error)")
                }
            }

            let nameFromData = entries.compactMap { $0.movie.groupName }.first

            isApplyingCloudUpdate = true
            self.movies = watched
            self.backlogMovies = backlog
            if let nameFromData, !(nameFromData.isEmpty) {
                self.currentGroupName = nameFromData
            }
            isApplyingCloudUpdate = false

            print("CloudKit: applied group data → watched: \(watched.count), backlog: \(backlog.count)")

            if entries.isEmpty {
                try await initialUploadIfNeeded(using: cloudStore)
            }

            // ✅ Automatische Migration (Cloud-Daten)
            await migrateCastDataIfNeeded()

        } catch {
            print("Fehler beim Laden aus CloudKit: \(error)")
        }
    }

    // MARK: - Public Refresh

    /// Lädt Movies/Ratings der aktuellen Gruppe erneut aus CloudKit.
    ///
    /// Wird genutzt für:
    /// - App kommt wieder in den Vordergrund
    /// - Pull-to-Refresh
    /// - manuelles Sync
    func refreshFromCloud(force: Bool = false) async {
        guard cloudStore != nil else { return }
        if isSyncing { return }

        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshAt = Date()

        await loadFromCloud()
    }


    private func initialUploadIfNeeded(using cloudStore: CloudKitMovieStore) async throws {
        print("CloudKit: initial upload starting (watched: \(movies.count), backlog: \(backlogMovies.count))")

        await withTaskGroup(of: Void.self) { group in
            for movie in movies {
                group.addTask {
                    do { try await cloudStore.save(movie: movie, isBacklog: false) }
                    catch { print("CloudKit initial upload (watched) error: \(error)") }
                }
            }

            for movie in backlogMovies {
                group.addTask {
                    do { try await cloudStore.save(movie: movie, isBacklog: true) }
                    catch { print("CloudKit initial upload (backlog) error: \(error)") }
                }
            }

            await group.waitForAll()
        }

        print("CloudKit: initial upload finished")
    }

    // MARK: - Cloud Sync bei Änderungen

    private func syncChanges(newList: [Movie], oldList: [Movie], isBacklog: Bool) async {
        guard let cloudStore else { return }
        if isApplyingCloudUpdate {
            print("CloudKit: syncChanges skipped (isApplyingCloudUpdate = true)")
            return
        }

        print("CloudKit: syncChanges START (isBacklog = \(isBacklog), newCount = \(newList.count), oldCount = \(oldList.count))")

        let oldById = Dictionary(uniqueKeysWithValues: oldList.map { ($0.id, $0) })
        let newById = Dictionary(uniqueKeysWithValues: newList.map { ($0.id, $0) })

        let oldIDs = Set(oldById.keys)
        let newIDs = Set(newById.keys)

        let removedIDs = oldIDs.subtracting(newIDs)
        for id in removedIDs {
            do {
                try await cloudStore.delete(movieID: id)
                print("CloudKit: deleted record for movieID \(id)")
            } catch {
                print("CloudKit delete error: \(error)")
            }
        }

        let changedMovies: [Movie] = newList.filter { movie in
            guard let oldMovie = oldById[movie.id] else { return true }
            return !moviesEqualIgnoringRatings(oldMovie, movie)
        }

        if changedMovies.isEmpty {
            print("CloudKit: syncChanges – no changed movies to upload")
            print("CloudKit: syncChanges END (isBacklog = \(isBacklog))")
            return
        }

        print("CloudKit: syncChanges – will upload \(changedMovies.count) movies (isBacklog = \(isBacklog))")

        await withTaskGroup(of: Void.self) { group in
            for movie in changedMovies {
                group.addTask {
                    do { try await cloudStore.save(movie: movie, isBacklog: isBacklog) }
                    catch { print("CloudKit save error: \(error)") }
                }
            }
            await group.waitForAll()
        }

        print("CloudKit: syncChanges END (isBacklog = \(isBacklog))")
    }

    
    // MARK: - Ratings (Version B: MovieRating Records)

    /// Merged Ratings: `incoming` überschreibt (case-insensitive) bestehende Ratings pro Reviewer.
    private func mergeRatings(existing: [Rating], incoming: [Rating]) -> [Rating] {
        var out = existing
        for r in incoming {
            if let idx = out.firstIndex(where: { $0.reviewerName.lowercased() == r.reviewerName.lowercased() }) {
                out[idx] = r
            } else {
                out.append(r)
            }
        }
        return out
    }

    /// Für Cloud-Sync vergleichen wir Movies **ohne** Ratings, weil Ratings separat in CloudKit liegen.
    private func moviesEqualIgnoringRatings(_ a: Movie, _ b: Movie) -> Bool {
        var aa = a
        var bb = b
        aa.ratings = []
        bb.ratings = []
        return aa == bb
    }

    /// Speichert/aktualisiert die Bewertung des aktuellen Users für einen Film.
    /// - Wichtig: Ratings werden in CloudKit als eigene Records gespeichert (MovieRating).
    func upsertRating(for movieId: UUID, rating: Rating) async -> Bool {
        // 1) Lokal in die UI-Models mergen (für sofortiges Feedback + Offline)
        if let idx = movies.firstIndex(where: { $0.id == movieId }) {
            var m = movies[idx]
            m.ratings = mergeRatings(existing: m.ratings, incoming: [rating])
            movies[idx] = m
        }
        if let idx = backlogMovies.firstIndex(where: { $0.id == movieId }) {
            var m = backlogMovies[idx]
            m.ratings = mergeRatings(existing: m.ratings, incoming: [rating])
            backlogMovies[idx] = m
        }

        // 2) Cloud speichern
        guard let cloudRatingStore else { return true }
        do {
            try await cloudRatingStore.saveRating(rating, movieId: movieId, groupId: currentGroupId)
            return true
        } catch {
            print("CloudKit rating save error: \(error)")
            return false
        }
    }

    /// Löscht die Bewertung eines Reviewers (case-insensitive) für einen Film.
    func deleteRating(for movieId: UUID, reviewerName: String) async -> Bool {
        // Lokal entfernen
        func remove(from list: inout [Movie]) {
            guard let idx = list.firstIndex(where: { $0.id == movieId }) else { return }
            var m = list[idx]
            m.ratings.removeAll { $0.reviewerName.lowercased() == reviewerName.lowercased() }
            list[idx] = m
        }
        remove(from: &movies)
        remove(from: &backlogMovies)

        guard let cloudRatingStore else { return true }
        do {
            try await cloudRatingStore.deleteRating(movieId: movieId, groupId: currentGroupId, reviewerName: reviewerName)
            return true
        } catch {
            print("CloudKit rating delete error: \(error)")
            return false
        }
    }

// MARK: - ✅ CAST Migration (Legacy → TMDb Person IDs)

    private func migrateCastDataIfNeeded() async {
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

    // MARK: - Gruppen API

    func createNewGroup(withName name: String) {
        let newId = UUID().uuidString

        currentGroupId = newId
        currentGroupName = name

        isApplyingCloudUpdate = true
        movies = []
        backlogMovies = []
        isApplyingCloudUpdate = false

        print("MovieStore: created NEW EMPTY group '\(name)' with id \(newId)")

        addOrUpdateCurrentGroupInKnownGroups()
    }

    func joinGroup(withInviteCode code: String) {
        currentGroupId = code
        currentGroupName = currentGroupName

        isApplyingCloudUpdate = true
        movies = []
        backlogMovies = []
        isApplyingCloudUpdate = false

        addOrUpdateCurrentGroupInKnownGroups()

        Task { await self.loadFromCloud() }
    }

    func leaveCurrentGroup() {
        guard let oldId = currentGroupId else { return }

        print("MovieStore: leaving group with id \(oldId)")

        knownGroups.removeAll { $0.id == oldId }

        currentGroupId = nil
        currentGroupName = nil

        isApplyingCloudUpdate = true
        movies = []
        backlogMovies = []
        isApplyingCloudUpdate = false

        Task { await self.loadFromCloud() }
    }

    // MARK: - bekannte Gruppen verwalten

    private func addOrUpdateCurrentGroupInKnownGroups() {
        guard let id = currentGroupId else { return }

        if let index = knownGroups.firstIndex(where: { $0.id == id }) {
            if let name = currentGroupName, !name.isEmpty, knownGroups[index].name != name {
                knownGroups[index].name = name
            }
        } else {
            let info = GroupInfo(id: id, name: currentGroupName)
            knownGroups.append(info)
        }
    }

    private func saveKnownGroups() {
        if let data = try? JSONEncoder().encode(knownGroups) {
            UserDefaults.standard.set(data, forKey: Self.knownGroupsKey)
        }
    }

    private static func loadKnownGroups() -> [GroupInfo] {
        guard let data = UserDefaults.standard.data(forKey: knownGroupsKey),
              let decoded = try? JSONDecoder().decode([GroupInfo].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Preview

    static func preview() -> MovieStore {
        let store = MovieStore(useCloud: false)
        if store.movies.isEmpty {
            store.movies = sampleMovies
        }
        return store
    }
}
