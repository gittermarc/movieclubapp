//
//  StatsViewModel.swift
//  filmfreaks
//
//  Cached aggregation model for StatsView.
//

import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {

    typealias UserStats = StatsUserStats
    typealias Snapshot = StatsSnapshot
    typealias SnapshotBuilder = @Sendable (Inputs) -> Snapshot
    typealias ActorSorter = @Sendable ([ActorEntry], [Int: Double]) -> [ActorEntry]

    struct Inputs: Equatable, Sendable {
        var movies: [Movie]
        var users: [User]
        var ratingDisplayMode: RatingDisplayMode
        var selectedRange: StatsTimeRange
        var selectedLocationFilter: String?
    }

    @Published private(set) var snapshot: Snapshot = .empty

    private let debounceNanos: UInt64
    private let actorsPopularitySortLimit: Int
    private let snapshotBuilder: SnapshotBuilder
    private let actorSorter: ActorSorter

    private var updateTask: Task<Void, Never>?
    private var buildGeneration: Int = 0
    private var lastInputs: Inputs?

    init(
        debounceNanos: UInt64 = 200_000_000,
        actorsPopularitySortLimit: Int = 50,
        snapshotBuilder: SnapshotBuilder? = nil,
        actorSorter: ActorSorter? = nil
    ) {
        self.debounceNanos = debounceNanos
        self.actorsPopularitySortLimit = actorsPopularitySortLimit
        self.snapshotBuilder = snapshotBuilder ?? { inputs in
            StatsSnapshotBuilder.computeSnapshot(
                movies: inputs.movies,
                users: inputs.users,
                ratingDisplayMode: inputs.ratingDisplayMode,
                selectedRange: inputs.selectedRange,
                selectedLocationFilter: inputs.selectedLocationFilter
            )
        }
        self.actorSorter = actorSorter ?? { actors, popularityByPersonId in
            StatsSnapshotBuilder.sortActors(
                actors: actors,
                popularityByPersonId: popularityByPersonId
            )
        }
    }

    func update(
        movies: [Movie],
        users: [User],
        ratingDisplayMode: RatingDisplayMode,
        selectedRange: StatsTimeRange,
        selectedLocationFilter: String?
    ) {
        update(
            Inputs(
                movies: movies,
                users: users,
                ratingDisplayMode: ratingDisplayMode,
                selectedRange: selectedRange,
                selectedLocationFilter: selectedLocationFilter
            )
        )
    }

    func update(_ inputs: Inputs) {
        guard shouldScheduleUpdate(for: inputs) else { return }

        buildGeneration += 1
        let generation = buildGeneration
        let debounceNanos = self.debounceNanos
        let snapshotBuilder = self.snapshotBuilder
        let actorSorter = self.actorSorter
        let actorsPopularitySortLimit = self.actorsPopularitySortLimit

        updateTask?.cancel()
        updateTask = Task { [inputs, generation, debounceNanos, snapshotBuilder, actorSorter, actorsPopularitySortLimit] in
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else { return }

            let base = await Task.detached(priority: .userInitiated) {
                snapshotBuilder(inputs)
            }.value

            guard !Task.isCancelled else { return }

            let ids = Self.actorIdsNeedingPopularity(
                from: base.actorsByCountRaw,
                visibleLimit: actorsPopularitySortLimit
            )
            await PersonPopularityStore.shared.preloadPopularity(for: ids)

            guard !Task.isCancelled else { return }

            let popularity = PersonPopularityStore.shared.popularitySnapshot()

            let sortedActors = await Task.detached(priority: .userInitiated) {
                actorSorter(base.actorsByCountRaw, popularity)
            }.value

            var final = base
            final.actorsByCountRaw = sortedActors

            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.buildGeneration == generation else { return }
                self.snapshot = final
            }
        }
    }

    private func shouldScheduleUpdate(for inputs: Inputs) -> Bool {
        if let lastInputs, lastInputs == inputs {
            return false
        }

        lastInputs = inputs
        return true
    }

    nonisolated private static func actorIdsNeedingPopularity(
        from actors: [ActorEntry],
        visibleLimit: Int
    ) -> [Int] {
        guard !actors.isEmpty else { return [] }

        let limit = max(1, visibleLimit)
        if actors.count <= limit {
            return actors.map { $0.personId }
        }

        let threshold = actors[limit - 1].count
        return actors
            .filter { $0.count >= threshold }
            .map { $0.personId }
    }
}
