//
//  MovieQuickAddEnrichmentQueue.swift
//  filmfreaks
//

import Foundation

actor MovieQuickAddEnrichmentQueue {
    static let shared = MovieQuickAddEnrichmentQueue()

    private let service: MovieQuickAddEnrichmentService
    private let maxConcurrentLoads: Int
    private var runningLoads = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var inFlight: [UUID: Task<MovieMetadataLoadedMoviePatch?, Never>] = [:]

    init(
        service: MovieQuickAddEnrichmentService = MovieQuickAddEnrichmentService(),
        maxConcurrentLoads: Int = 2
    ) {
        self.service = service
        self.maxConcurrentLoads = max(1, maxConcurrentLoads)
    }

    func loadPatch(for request: MovieQuickAddEnrichmentRequest) async -> MovieMetadataLoadedMoviePatch? {
        guard MovieQuickAddEnrichmentService.needsEnrichment(movie: request.movieSnapshot) else {
            return nil
        }

        if let task = inFlight[request.movieId] {
            return await task.value
        }

        let task = Task.detached { [service] in
            await self.acquireLoadSlot()
            let patch = await service.loadPatch(for: request)
            await self.releaseLoadSlot()
            return patch
        }

        inFlight[request.movieId] = task
        let patch = await task.value
        inFlight[request.movieId] = nil
        return patch
    }

    func cancelAll() {
        for task in inFlight.values {
            task.cancel()
        }
        inFlight.removeAll()
        runningLoads = 0
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }

    private func acquireLoadSlot() async {
        if runningLoads < maxConcurrentLoads {
            runningLoads += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func releaseLoadSlot() {
        if waiters.isEmpty {
            runningLoads = max(0, runningLoads - 1)
            return
        }

        let continuation = waiters.removeFirst()
        continuation.resume()
    }
}
