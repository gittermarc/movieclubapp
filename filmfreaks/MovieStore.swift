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

            // Cheaper than JSON encoding (and avoids doing work twice).
            if oldValue == movies { return }

            PersistenceManager.shared.saveMovies(movies, groupId: currentGroupId)

            if cloudStore != nil {
                enqueueCloudSync(newList: movies, oldList: oldValue, isBacklog: false)
            }
        }
    }

    @Published var backlogMovies: [Movie] = [] {
        didSet {
            if isApplyingCloudUpdate { return }

            if oldValue == backlogMovies { return }

            PersistenceManager.shared.saveBacklogMovies(backlogMovies, groupId: currentGroupId)

            if cloudStore != nil {
                enqueueCloudSync(newList: backlogMovies, oldList: oldValue, isBacklog: true)
            }
        }
    }

    @Published var isSyncing: Bool = false

    // MARK: - Sync transparency (per group)

    /// Number of locally queued changes that still need to be pushed to iCloud.
    @Published var pendingCloudChangesCount: Int = 0

    /// Timestamp of the last successful sync (fetch or upload) for the current group.
    @Published var lastCloudSyncAt: Date?

    /// Last sync error message (best effort). Cleared on success.
    @Published var lastCloudSyncError: String?

    @Published var currentGroupId: String? {
        didSet {
            UserDefaults.standard.set(currentGroupId, forKey: "CurrentGroupId")
            addOrUpdateCurrentGroupInKnownGroups()

            // Load per-group sync meta (pending, last sync, last error)
            loadSyncMetaForCurrentGroup()
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

    // ✅ must be var: we initialize it only after `self` is fully initialized
    private var cloudSyncCoordinator: MovieCloudSyncCoordinator?

    private var isApplyingCloudUpdate = false

    // Combined sync state (fetch + upload). We use a counter to avoid flicker.
    private var syncCount: Int = 0
    private var isRefreshingFromCloud: Bool = false

    // Throttle gegen zu viele Cloud-Fetches
    private var lastRefreshAt: Date?
    private let minRefreshInterval: TimeInterval = 8

    private static let knownGroupsKey = "KnownGroups"

    // UserDefaults base key (per group)
    private static let syncMetaPrefix = "MovieStore.SyncMeta."

    // ✅ Migration Guard
    private var isMigratingCast = false

    init(useCloud: Bool = true) {

        // 1) Initialize all stored properties WITHOUT capturing `self`
        if useCloud {
            self.cloudStore = CloudKitMovieStore()
            self.cloudRatingStore = CloudKitRatingStore()
        } else {
            self.cloudStore = nil
            self.cloudRatingStore = nil
        }
        self.cloudSyncCoordinator = nil

        // 2) Load persisted state
        self.knownGroups = Self.loadKnownGroups()

        self.currentGroupId = UserDefaults.standard.string(forKey: "CurrentGroupId")
        self.currentGroupName = UserDefaults.standard.string(forKey: "CurrentGroupName")

        // Load per-group sync meta (pending, last sync, last error)
        loadSyncMetaForCurrentGroup()

        addOrUpdateCurrentGroupInKnownGroups()

        // 3) Load local caches without triggering persistence/sync noise
        isApplyingCloudUpdate = true
        let stored = PersistenceManager.shared.loadMovies(groupId: currentGroupId)
        self.movies = stored

        let backlogStored = PersistenceManager.shared.loadBacklogMovies(groupId: currentGroupId)
        self.backlogMovies = backlogStored
        isApplyingCloudUpdate = false

        // ✅ Automatische Migration (lokale Daten)
        Task { await self.migrateCastDataIfNeeded() }

        // 4) Now `self` is fully initialized -> safe to capture `self` in closures
        if useCloud, let cloudStore = self.cloudStore {
            self.cloudSyncCoordinator = MovieCloudSyncCoordinator(
                cloudStore: cloudStore,
                groupIdProvider: { [weak self] in self?.currentGroupId },
                beginSync: { [weak self] in self?.beginSync() },
                endSync: { [weak self] in self?.endSync() },
                networkIsAvailable: { NetworkMonitor.shared.isConnected },
                pendingCountDidChange: { [weak self] count, groupId in
                    self?.applyPendingCount(count, forGroupId: groupId)
                },
                batchDidSucceed: { [weak self] groupId in
                    self?.markCloudSyncSuccess(forGroupId: groupId)
                },
                batchDidFail: { [weak self] error, groupId in
                    self?.markCloudSyncFailure(error, forGroupId: groupId)
                }
            )

            // Load initial sync meta (now that we have currentGroupId).
            loadSyncMetaForCurrentGroup()

            Task { await self.loadFromCloud() }
        }
    }

    // MARK: - Cloud Laden

    private func loadFromCloud() async {
        guard let cloudStore else { return }

        if isRefreshingFromCloud { return }
        isRefreshingFromCloud = true

        print("CloudKit: loadFromCloud() START (groupId=\(currentGroupId ?? "nil"))")
        beginSync()
        defer {
            endSync()
            isRefreshingFromCloud = false
            print("CloudKit: loadFromCloud() END (groupId=\(currentGroupId ?? "nil"))")
        }

        do {
            // Capture the group id at the start so a mid-flight group switch can't
            // accidentally apply results to the wrong group.
            let requestedGroupId = currentGroupId
            let gid = requestedGroupId
            let isZoneGroup: Bool = {
                guard let gid, !gid.isEmpty else { return false }
                return GroupContextStore.context(forGroupId: gid) != nil
            }()

            var watched: [Movie] = []
            var backlog: [Movie] = []

            if isZoneGroup {
                // Phase 2: inkrementell per Zone-Changes.
                let changes = try await cloudStore.fetchMovieChanges(forGroupId: gid)
                print("CloudKit: zone changes movies → changed: \(changes.changed.count), deleted: \(changes.deletedMovieIDs.count), initial: \(changes.isInitial)")

                // Start from current local state (local-first) and apply deltas.
                watched = self.movies
                backlog = self.backlogMovies

                // Remove deletes
                if !changes.deletedMovieIDs.isEmpty {
                    let del = Set(changes.deletedMovieIDs)
                    watched.removeAll { del.contains($0.id) }
                    backlog.removeAll { del.contains($0.id) }
                }

                // Apply changes (replace/move/insert)
                for entry in changes.changed {
                    let id = entry.movie.id
                    watched.removeAll { $0.id == id }
                    backlog.removeAll { $0.id == id }
                    if entry.isBacklog {
                        backlog.append(entry.movie)
                    } else {
                        watched.append(entry.movie)
                    }
                }

                // If this was an initial zone fetch and we got no records, the zone is empty.
                if changes.isInitial && changes.changed.isEmpty && changes.deletedMovieIDs.isEmpty {
                    try await initialUploadIfNeeded(using: cloudStore)
                }

            } else {
                // Legacy / public DB: full fetch per query
                let entries = try await cloudStore.fetchMovies(forGroupId: gid)
                print("CloudKit: fetchMovies(forGroupId:) returned \(entries.count) entries")
                watched = entries.filter { !$0.isBacklog }.map { $0.movie }
                backlog = entries.filter { $0.isBacklog }.map { $0.movie }

                if entries.isEmpty {
                    try await initialUploadIfNeeded(using: cloudStore)
                }
            }

            // ✅ Ratings sind eigene CloudKit-Records (MovieRating).
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
                    if isZoneGroup {
                        // Phase 2: inkrementell per Zone-Changes
                        let changes = try await cloudRatingStore.fetchRatingChanges(forGroupId: gid)
                        let changedTotal = changes.changedByMovieId.values.reduce(0) { $0 + $1.count }
                        print("CloudKit: zone changes ratings → changed: \(changedTotal), deleted: \(changes.deletedKeys.count), initial: \(changes.isInitial)")

                        watched = watched.map { m in
                            var copy = m
                            if let incoming = changes.changedByMovieId[copy.id] {
                                copy.ratings = mergeRatings(existing: copy.ratings, incoming: incoming)
                            }
                            if !changes.deletedKeys.isEmpty {
                                let delKeys = changes.deletedKeys.filter { $0.movieId == copy.id }.map { $0.reviewerKey }
                                if !delKeys.isEmpty {
                                    let delSet = Set(delKeys)
                                    copy.ratings.removeAll { delSet.contains(reviewerKey($0)) }
                                }
                            }
                            return copy
                        }
                        backlog = backlog.map { m in
                            var copy = m
                            if let incoming = changes.changedByMovieId[copy.id] {
                                copy.ratings = mergeRatings(existing: copy.ratings, incoming: incoming)
                            }
                            if !changes.deletedKeys.isEmpty {
                                let delKeys = changes.deletedKeys.filter { $0.movieId == copy.id }.map { $0.reviewerKey }
                                if !delKeys.isEmpty {
                                    let delSet = Set(delKeys)
                                    copy.ratings.removeAll { delSet.contains(reviewerKey($0)) }
                                }
                            }
                            return copy
                        }

                    } else {
                        // Legacy/public: query by movie ids (chunked)
                        let ids = Array(Set(watched.map(\.id) + backlog.map(\.id)))
                        let cloudRatingsByMovieId = try await cloudRatingStore.fetchRatings(forGroupId: gid, movieIds: ids)

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
                    }
                } catch {
                    print("CloudKit: ratings fetch error: \(error)")
                }
            }

            let nameFromData: String? = {
                // In Zone-Gruppen brauchen wir keine Entries-Liste mehr; best-effort aus den Movies.
                (watched + backlog).compactMap { $0.groupName }.first
            }()

            // If the user switched groups while we were fetching, do NOT apply these results.
            // (Otherwise we can temporarily show the wrong group's movies.)
            guard groupKey(requestedGroupId) == groupKey(currentGroupId) else {
                print("CloudKit: discard loadFromCloud result (group switched: requested=\(requestedGroupId ?? "nil"), active=\(currentGroupId ?? "nil"))")
                return
            }

            isApplyingCloudUpdate = true
            self.movies = watched
            self.backlogMovies = backlog
            if let nameFromData, !(nameFromData.isEmpty) {
                self.currentGroupName = nameFromData
            }
            isApplyingCloudUpdate = false

            // 🔑 IMPORTANT:
            // For zone-based groups we sync incrementally via change tokens.
            // That means on the *next* app start, we need a local baseline to apply deltas onto.
            // Cloud-applied updates are therefore persisted explicitly (even though we suppress didSet).
            PersistenceManager.shared.saveMovies(watched, groupId: requestedGroupId)
            PersistenceManager.shared.saveBacklogMovies(backlog, groupId: requestedGroupId)

            print("CloudKit: applied group data → watched: \(watched.count), backlog: \(backlog.count)")

            // A successful fetch counts as a successful sync.
            markCloudSyncSuccess(forGroupId: currentGroupId)

            // ✅ Automatische Migration (Cloud-Daten)
            await migrateCastDataIfNeeded()

        } catch {
            markCloudSyncFailure(error, forGroupId: currentGroupId)
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
        if isRefreshingFromCloud { return }

        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshAt = Date()

        await loadFromCloud()
    }

    /// Triggers an immediate upload attempt for any queued local changes.
    /// Useful when the device just came back online.
    func flushPendingCloudChanges() {
        cloudSyncCoordinator?.flushImmediately()
    }

    // MARK: - Sync state helpers

    private func beginSync() {
        syncCount += 1
        if !isSyncing { isSyncing = true }
    }

    private func endSync() {
        syncCount = max(0, syncCount - 1)
        let shouldSync = syncCount > 0
        if isSyncing != shouldSync { isSyncing = shouldSync }
    }

    private func initialUploadIfNeeded(using cloudStore: CloudKitMovieStore) async throws {
        print("CloudKit: initial upload starting (watched: \(movies.count), backlog: \(backlogMovies.count))")

        // Batch upload instead of one record per Task.
        let items = movies.map { ($0, false) } + backlogMovies.map { ($0, true) }
        do {
            beginSync()
            defer { endSync() }
            try await cloudStore.modifyBatch(
                saveItems: items,
                deleteIDs: [],
                groupIdForDeletes: currentGroupId
            )
            markCloudSyncSuccess(forGroupId: currentGroupId)
        } catch {
            // Best-effort; even if some records fail, the next refresh will reconcile.
            markCloudSyncFailure(error, forGroupId: currentGroupId)
            print("CloudKit initial upload error: \(error)")
        }

        print("CloudKit: initial upload finished")
    }

    // MARK: - Sync meta persistence (per group)

    private func groupKey(_ groupId: String?) -> String {
        let gid = (groupId ?? currentGroupId)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return gid.isEmpty ? "__default__" : gid
    }

    private func syncKey(_ suffix: String, groupId: String?) -> String {
        Self.syncMetaPrefix + groupKey(groupId) + "." + suffix
    }

    private func loadSyncMetaForCurrentGroup() {
        let gid = currentGroupId
        let defaults = UserDefaults.standard
        pendingCloudChangesCount = defaults.integer(forKey: syncKey("pendingCount", groupId: gid))
        lastCloudSyncAt = defaults.object(forKey: syncKey("lastSyncAt", groupId: gid)) as? Date
        lastCloudSyncError = defaults.string(forKey: syncKey("lastError", groupId: gid))
    }

    private func applyPendingCount(_ count: Int, forGroupId groupId: String?) {
        let defaults = UserDefaults.standard

        // Persist per group, but only update UI if this is the active group.
        defaults.set(count, forKey: syncKey("pendingCount", groupId: groupId))

        if groupKey(groupId) == groupKey(currentGroupId) {
            pendingCloudChangesCount = count
        }
    }

    private func markCloudSyncSuccess(forGroupId groupId: String?) {
        let date = Date()
        let defaults = UserDefaults.standard
        defaults.set(date, forKey: syncKey("lastSyncAt", groupId: groupId))
        defaults.removeObject(forKey: syncKey("lastError", groupId: groupId))

        if groupKey(groupId) == groupKey(currentGroupId) {
            lastCloudSyncAt = date
            lastCloudSyncError = nil
        }
    }

    private func markCloudSyncFailure(_ error: Error, forGroupId groupId: String?) {
        let message = String(describing: error)
        let defaults = UserDefaults.standard
        defaults.set(message, forKey: syncKey("lastError", groupId: groupId))

        if groupKey(groupId) == groupKey(currentGroupId) {
            lastCloudSyncError = message
        }
    }

    // MARK: - Cloud Sync bei Änderungen (debounced + batched)

    private func enqueueCloudSync(newList: [Movie], oldList: [Movie], isBacklog: Bool) {
        guard let coordinator = cloudSyncCoordinator else { return }
        if isApplyingCloudUpdate { return }

        let oldById = Dictionary(uniqueKeysWithValues: oldList.map { ($0.id, $0) })
        let newById = Dictionary(uniqueKeysWithValues: newList.map { ($0.id, $0) })

        let removedIDs = Set(oldById.keys).subtracting(Set(newById.keys))
        for id in removedIDs {
            coordinator.queueDelete(movieID: id)
        }

        let changedMovies: [Movie] = newList.filter { movie in
            guard let oldMovie = oldById[movie.id] else { return true }
            return !moviesEqualIgnoringRatings(oldMovie, movie)
        }
        for movie in changedMovies {
            coordinator.queueSave(movie: movie, isBacklog: isBacklog)
        }
    }

    // MARK: - Ratings (Version B: MovieRating Records)

    /// Stable reviewer identity key used to merge ratings.
    private func reviewerKey(_ r: Rating) -> String {
        if let rid = r.reviewerId { return rid.uuidString.lowercased() }
        if let gid = currentGroupId, !gid.isEmpty {
            return StableID.deterministicUUID(forName: r.reviewerName, groupId: gid).uuidString.lowercased()
        }
        return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Ensures reviewerId is present for legacy ratings (best-effort).
    private func normalizedRating(_ r: Rating) -> Rating {
        var copy = r
        if copy.reviewerId == nil, let gid = currentGroupId, !gid.isEmpty {
            copy.reviewerId = StableID.deterministicUUID(forName: copy.reviewerName, groupId: gid)
        }
        return copy
    }

    /// Merged Ratings: `incoming` überschreibt bestehende Ratings pro Reviewer (stabile IDs).
    private func mergeRatings(existing: [Rating], incoming: [Rating]) -> [Rating] {
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

    private func loadLocalCache(for groupId: String?) {
        isApplyingCloudUpdate = true
        movies = PersistenceManager.shared.loadMovies(groupId: groupId)
        backlogMovies = PersistenceManager.shared.loadBacklogMovies(groupId: groupId)
        isApplyingCloudUpdate = false
    }

    func createNewGroup(withName name: String) {
        let newId = UUID().uuidString

        currentGroupId = newId
        currentGroupName = name

        // Neue Gruppe startet leer – wir laden trotzdem den lokalen Cache,
        // damit die Persistenz group-scoped sauber greift.
        loadLocalCache(for: newId)

        print("MovieStore: created NEW EMPTY group '\(name)' with id \(newId)")

        addOrUpdateCurrentGroupInKnownGroups()
    }

    func joinGroup(withInviteCode code: String) {
        currentGroupId = code
        currentGroupName = currentGroupName

        // Erst lokal (schnell), danach Cloud (Autorität)
        loadLocalCache(for: code)

        addOrUpdateCurrentGroupInKnownGroups()

        Task { await self.loadFromCloud() }
    }

    /// Aktiviert eine CloudKit-Sharing Gruppe (private/shared DB) als aktuelle Gruppe.
    func activateCloudGroup(_ group: GroupContext) {
        currentGroupId = group.id
        currentGroupName = group.name

        // Erst lokal (schnell), danach Cloud (Autorität)
        loadLocalCache(for: group.id)
        addOrUpdateCurrentGroupInKnownGroups()

        Task { await self.loadFromCloud() }
    }

    func leaveCurrentGroup() {
        guard let oldId = currentGroupId else { return }

        print("MovieStore: leaving group with id \(oldId)")

        knownGroups.removeAll { $0.id == oldId }

        currentGroupId = nil
        currentGroupName = nil

        // Fallback auf "default"-Gruppe (lokal) – danach (best effort) Cloud-Reload.
        loadLocalCache(for: nil)

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
