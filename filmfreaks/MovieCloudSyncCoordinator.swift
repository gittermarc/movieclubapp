//
//  MovieCloudSyncCoordinator.swift
//  filmfreaks
//
//  Debounced + batched CloudKit sync for Movies.
//

import Foundation

/// Debounced + batched CloudKit writer for movie changes.
///
/// This intentionally lives on the MainActor:
/// - `MovieStore` mutates on MainActor
/// - avoids Sendable issues when caching `Movie` structs in an async actor
/// - still performs the actual CloudKit call asynchronously
@MainActor
final class MovieCloudSyncCoordinator {

    struct PendingSave {
        var movie: Movie
        var isBacklog: Bool
        /// Token to detect whether a newer version of the same item was queued while a flush was in flight.
        var token: UUID
    }

    struct PendingDelete {
        var token: UUID
    }

    private let cloudStore: CloudKitMovieStore
    private let groupIdProvider: () -> String?
    private let beginSync: () -> Void
    private let endSync: () -> Void
    private let networkIsAvailable: () -> Bool
    private let pendingCountDidChange: (_ count: Int, _ groupId: String?) -> Void
    private let batchDidSucceed: (_ groupId: String?) -> Void
    private let batchDidFail: (_ error: Error, _ groupId: String?) -> Void
    private let dirtyJournal: MovieCloudDirtyJournal

    private let debounceNanoseconds: UInt64
    private var pendingSaves: [UUID: PendingSave] = [:]
    private var pendingDeletes: [UUID: PendingDelete] = [:]
    private var scheduledFlush: Task<Void, Never>?
    private var isFlushing: Bool = false

    init(
        cloudStore: CloudKitMovieStore,
        debounce: TimeInterval = 0.8,
        groupIdProvider: @escaping () -> String?,
        beginSync: @escaping () -> Void,
        endSync: @escaping () -> Void,
        networkIsAvailable: @escaping () -> Bool,
        pendingCountDidChange: @escaping (_ count: Int, _ groupId: String?) -> Void,
        batchDidSucceed: @escaping (_ groupId: String?) -> Void,
        batchDidFail: @escaping (_ error: Error, _ groupId: String?) -> Void,
        dirtyJournal: MovieCloudDirtyJournal = .shared
    ) {
        self.cloudStore = cloudStore
        self.groupIdProvider = groupIdProvider
        self.beginSync = beginSync
        self.endSync = endSync
        self.networkIsAvailable = networkIsAvailable
        self.pendingCountDidChange = pendingCountDidChange
        self.batchDidSucceed = batchDidSucceed
        self.batchDidFail = batchDidFail
        self.dirtyJournal = dirtyJournal

        let ns = max(0.05, debounce) * 1_000_000_000
        self.debounceNanoseconds = UInt64(ns)
    }

    func queueSave(movie: Movie, isBacklog: Bool) {
        let groupId = groupIdProvider()
        let token = UUID()
        dirtyJournal.recordSave(movie: movie, isBacklog: isBacklog, groupId: groupId, token: token)
        pendingSaves[movie.id] = PendingSave(movie: movie, isBacklog: isBacklog, token: token)
        pendingDeletes.removeValue(forKey: movie.id)
        publishPendingCount()
        scheduleFlush()
    }

    func queueDelete(movieID: UUID) {
        let groupId = groupIdProvider()
        let token = UUID()
        dirtyJournal.recordDelete(movieID: movieID, groupId: groupId, token: token)
        pendingSaves.removeValue(forKey: movieID)
        pendingDeletes[movieID] = PendingDelete(token: token)
        publishPendingCount()
        scheduleFlush()
    }

    func restorePendingChangesFromJournal(watchedMovies: [Movie], backlogMovies: [Movie]) {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        pendingSaves.removeAll()
        pendingDeletes.removeAll()

        let groupId = groupIdProvider()
        let entries = dirtyJournal.entries(groupId: groupId)

        var watchedByID: [UUID: Movie] = [:]
        watchedByID.reserveCapacity(watchedMovies.count)
        for movie in watchedMovies {
            watchedByID[movie.id] = movie
        }

        var backlogByID: [UUID: Movie] = [:]
        backlogByID.reserveCapacity(backlogMovies.count)
        for movie in backlogMovies {
            backlogByID[movie.id] = movie
        }

        for entry in entries {
            switch entry.operation {
            case .save:
                let resolvedMovie = entry.movie ?? watchedByID[entry.movieId] ?? backlogByID[entry.movieId]
                let resolvedIsBacklog: Bool = {
                    if let isBacklog = entry.isBacklog {
                        return isBacklog
                    }

                    return backlogByID[entry.movieId] != nil
                }()

                guard let resolvedMovie else { continue }

                pendingSaves[entry.movieId] = PendingSave(
                    movie: resolvedMovie,
                    isBacklog: resolvedIsBacklog,
                    token: entry.token
                )
                pendingDeletes.removeValue(forKey: entry.movieId)

            case .delete:
                pendingSaves.removeValue(forKey: entry.movieId)
                pendingDeletes[entry.movieId] = PendingDelete(token: entry.token)
            }
        }

        publishPendingCount()

        if !pendingSaves.isEmpty || !pendingDeletes.isEmpty {
            scheduleFlush()
        }
    }

    /// Useful for "I just did a bulk change, please push now" moments.
    func flushImmediately() {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        Task { await self.flushNow() }
    }

    private func scheduleFlush() {
        scheduledFlush?.cancel()
        scheduledFlush = Task { [debounceNanoseconds] in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            await self.flushNow()
        }
    }

    private func flushNow() async {
        if isFlushing { return }
        guard networkIsAvailable() else { return }

        let groupId = groupIdProvider()
        let savesSnapshot = pendingSaves
        let deletesSnapshot = pendingDeletes

        guard !savesSnapshot.isEmpty || !deletesSnapshot.isEmpty else { return }
        isFlushing = true

        beginSync()
        defer {
            endSync()
            isFlushing = false
        }

        do {
            try await cloudStore.modifyBatch(
                saveItems: savesSnapshot.values.map { ($0.movie, $0.isBacklog) },
                deleteIDs: Array(deletesSnapshot.keys),
                groupIdForDeletes: groupId
            )

            // Only remove entries that haven't been superseded while the flush was in flight.
            for (id, sent) in savesSnapshot {
                if let current = pendingSaves[id], current.token == sent.token {
                    pendingSaves.removeValue(forKey: id)
                    dirtyJournal.remove(movieID: id, matchingToken: sent.token, groupId: groupId)
                }
            }
            for (id, sent) in deletesSnapshot {
                if let current = pendingDeletes[id], current.token == sent.token {
                    pendingDeletes.removeValue(forKey: id)
                    dirtyJournal.remove(movieID: id, matchingToken: sent.token, groupId: groupId)
                }
            }

            publishPendingCount()
            batchDidSucceed(groupId)

            // If new changes arrived during the flush, schedule another pass quickly.
            if !pendingSaves.isEmpty || !pendingDeletes.isEmpty {
                scheduleFlush()
            }

        } catch {
            // Keep pending changes so the UI can show "ausstehend" and we can retry later.
            batchDidFail(error, groupId)
            publishPendingCount()
        }
    }

    private func publishPendingCount() {
        pendingCountDidChange(pendingSaves.count + pendingDeletes.count, groupIdProvider())
    }
}
