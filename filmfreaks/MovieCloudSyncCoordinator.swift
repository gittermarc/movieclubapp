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
        batchDidFail: @escaping (_ error: Error, _ groupId: String?) -> Void
    ) {
        self.cloudStore = cloudStore
        self.groupIdProvider = groupIdProvider
        self.beginSync = beginSync
        self.endSync = endSync
        self.networkIsAvailable = networkIsAvailable
        self.pendingCountDidChange = pendingCountDidChange
        self.batchDidSucceed = batchDidSucceed
        self.batchDidFail = batchDidFail

        let ns = max(0.05, debounce) * 1_000_000_000
        self.debounceNanoseconds = UInt64(ns)
    }

    func queueSave(movie: Movie, isBacklog: Bool) {
        pendingSaves[movie.id] = PendingSave(movie: movie, isBacklog: isBacklog, token: UUID())
        pendingDeletes.removeValue(forKey: movie.id)
        publishPendingCount()
        scheduleFlush()
    }

    func queueDelete(movieID: UUID) {
        pendingSaves.removeValue(forKey: movieID)
        pendingDeletes[movieID] = PendingDelete(token: UUID())
        publishPendingCount()
        scheduleFlush()
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
                }
            }
            for (id, sent) in deletesSnapshot {
                if let current = pendingDeletes[id], current.token == sent.token {
                    pendingDeletes.removeValue(forKey: id)
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
