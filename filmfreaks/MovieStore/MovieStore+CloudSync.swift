//
//  MovieStore+CloudSync.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

import Foundation
import Combine

internal extension MovieStore {

    // MARK: - Setup

    func configureCloudSyncIfNeeded(useCloud: Bool) {
        guard useCloud, let cloudStore = self.cloudStore else { return }

        cloudSyncCoordinator = MovieCloudSyncCoordinator(
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
        restorePendingMovieCloudWritesForCurrentGroup()

        Task { await self.loadFromCloud() }
    }

    func setupGroupContextRetryHandling() {
        groupContextCancellable = NotificationCenter.default.publisher(for: .groupContextDidUpsert)
            .compactMap { $0.userInfo?["groupId"] as? String }
            .sink { [weak self] groupId in
                guard let self else { return }
                Task { @MainActor in
                    self.handleGroupContextUpsert(groupId: groupId)
                }
            }
    }

    func setupNetworkReconnectHandling() {
        // Seed with current state so we only react to *transitions*.
        lastNetworkConnected = NetworkMonitor.shared.isConnected

        networkCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }

                Task { @MainActor in
                    let wasConnected = self.lastNetworkConnected
                    self.lastNetworkConnected = connected

                    // Only flush on offline → online.
                    guard connected, !wasConnected else { return }
                    self.flushPendingCloudChanges()
                }
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

    func restorePendingMovieCloudWritesForCurrentGroup() {
        cloudSyncCoordinator?.restorePendingChangesFromJournal(
            watchedMovies: movies,
            backlogMovies: backlogMovies
        )
    }

    // MARK: - Cloud Laden

    func loadFromCloud() async {
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

            // Safety: UUID-like groupIds are treated as Sharing/Zone groups.
            // If the GroupContext isn't ready yet, we must not fall back to Public DB.
            if let gid, !gid.isEmpty,
               CloudKitRouting.requiresGroupContext(for: gid),
               GroupContextStore.context(forGroupId: gid) == nil {
                throw CloudKitRoutingError.groupContextNotReady(groupId: gid)
            }
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

    // MARK: - Change propagation into CloudSyncCoordinator

    func enqueueCloudSync(newList: [Movie], oldList: [Movie], isBacklog: Bool) {
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
}

private extension MovieStore {

    func handleGroupContextUpsert(groupId: String) {
        guard let normalized = CloudKitRouting.normalizedGroupId(groupId) else { return }
        guard let current = CloudKitRouting.normalizedGroupId(currentGroupId) else { return }
        guard normalized == current else { return }

        // Only relevant for UUID-like groupIds.
        guard CloudKitRouting.requiresGroupContext(for: normalized) else { return }
        guard GroupContextStore.context(forGroupId: normalized) != nil else { return }

        // Throttle duplicate upserts (group list refresh may upsert multiple times).
        let now = Date()
        if let last = lastGroupContextRetryAtByGroup[normalized], now.timeIntervalSince(last) < minGroupContextRetryInterval {
            return
        }
        lastGroupContextRetryAtByGroup[normalized] = now

        // If routing just became available, try to push pending writes and then fetch deltas.
        flushPendingCloudChanges()
        Task { await self.refreshFromCloud(force: true) }
    }

    // MARK: - Sync state helpers

    func beginSync() {
        syncCount += 1
        if !isSyncing { isSyncing = true }
    }

    func endSync() {
        syncCount = max(0, syncCount - 1)
        let shouldSync = syncCount > 0
        if isSyncing != shouldSync { isSyncing = shouldSync }
    }

    func initialUploadIfNeeded(using cloudStore: CloudKitMovieStore) async throws {
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

    /// Für Cloud-Sync vergleichen wir Movies **ohne** Ratings, weil Ratings separat in CloudKit liegen.
    func moviesEqualIgnoringRatings(_ a: Movie, _ b: Movie) -> Bool {
        var aa = a
        var bb = b
        aa.ratings = []
        bb.ratings = []
        return aa == bb
    }
}
