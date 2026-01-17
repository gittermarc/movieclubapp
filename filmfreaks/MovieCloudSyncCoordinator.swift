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
    }

    private let cloudStore: CloudKitMovieStore
    private let groupIdProvider: () -> String?
    private let beginSync: () -> Void
    private let endSync: () -> Void

    private let debounceNanoseconds: UInt64
    private var pendingSaves: [UUID: PendingSave] = [:]
    private var pendingDeletes: Set<UUID> = []
    private var scheduledFlush: Task<Void, Never>?

    init(
        cloudStore: CloudKitMovieStore,
        debounce: TimeInterval = 0.8,
        groupIdProvider: @escaping () -> String?,
        beginSync: @escaping () -> Void,
        endSync: @escaping () -> Void
    ) {
        self.cloudStore = cloudStore
        self.groupIdProvider = groupIdProvider
        self.beginSync = beginSync
        self.endSync = endSync

        let ns = max(0.05, debounce) * 1_000_000_000
        self.debounceNanoseconds = UInt64(ns)
    }

    func queueSave(movie: Movie, isBacklog: Bool) {
        pendingSaves[movie.id] = PendingSave(movie: movie, isBacklog: isBacklog)
        pendingDeletes.remove(movie.id)
        scheduleFlush()
    }

    func queueDelete(movieID: UUID) {
        pendingSaves.removeValue(forKey: movieID)
        pendingDeletes.insert(movieID)
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
        let saves = Array(pendingSaves.values)
        let deletes = Array(pendingDeletes)
        guard !saves.isEmpty || !deletes.isEmpty else { return }

        pendingSaves.removeAll(keepingCapacity: true)
        pendingDeletes.removeAll(keepingCapacity: true)

        beginSync()
        defer { endSync() }

        do {
            try await cloudStore.modifyBatch(
                saveItems: saves.map { ($0.movie, $0.isBacklog) },
                deleteIDs: deletes,
                groupIdForDeletes: groupIdProvider()
            )
        } catch {
            // Best-effort. The next user interaction or manual refresh will reconcile anyway.
            print("CloudKit batch modify error: \(error)")
        }
    }
}
