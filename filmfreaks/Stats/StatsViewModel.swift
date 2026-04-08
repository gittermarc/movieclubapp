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

    @Published private(set) var snapshot: Snapshot = .empty

    private let debounceNanos: UInt64 = 200_000_000
    private let actorsPopularitySortLimit: Int = 50
    private var updateTask: Task<Void, Never>?
    private var buildGeneration: Int = 0

    private struct Inputs: Equatable {
        var movies: [Movie]
        var users: [User]
        var ratingDisplayMode: RatingDisplayMode
        var selectedRange: StatsTimeRange
        var selectedLocationFilter: String?
    }

    private var lastInputs: Inputs?

    func update(
        movies: [Movie],
        users: [User],
        ratingDisplayMode: RatingDisplayMode,
        selectedRange: StatsTimeRange,
        selectedLocationFilter: String?
    ) {
        let inputs = Inputs(
            movies: movies,
            users: users,
            ratingDisplayMode: ratingDisplayMode,
            selectedRange: selectedRange,
            selectedLocationFilter: selectedLocationFilter
        )

        if let lastInputs, lastInputs == inputs {
            return
        }
        lastInputs = inputs

        // Debounce and compute off-main to avoid UI stalls when multiple .onChange triggers fire.
        buildGeneration += 1
        let generation = buildGeneration

        let debounceNanos = self.debounceNanos
        let actorsPopularitySortLimit = self.actorsPopularitySortLimit

        updateTask?.cancel()
        updateTask = Task { [inputs, debounceNanos, actorsPopularitySortLimit] in
            try? await Task.sleep(nanoseconds: debounceNanos)
            guard !Task.isCancelled else { return }

            // 1) Base snapshot off-main.
            let base = await Task.detached(priority: .userInitiated) {
                StatsSnapshotBuilder.computeSnapshot(
                    movies: inputs.movies,
                    users: inputs.users,
                    ratingDisplayMode: inputs.ratingDisplayMode,
                    selectedRange: inputs.selectedRange,
                    selectedLocationFilter: inputs.selectedLocationFilter
                )
            }.value

            guard !Task.isCancelled else { return }

            // 2) Ensure popularity exists for the *final* visible top-actors BEFORE we publish.
            //    (Wichtig: wenn viele Darsteller die gleiche Häufigkeit haben, müssen wir die
            //    komplette "Schwellwert"-Gruppe laden – sonst ist das Top-50 Ergebnis falsch.)
            let ids: [Int] = {
                let actors = base.actorsByCountRaw
                guard !actors.isEmpty else { return [] }

                let limit = max(1, actorsPopularitySortLimit)
                if actors.count <= limit {
                    return actors.map { $0.personId }
                }

                let threshold = actors[limit - 1].count
                return actors
                    .filter { $0.count >= threshold }
                    .map { $0.personId }
            }()
            await PersonPopularityStore.shared.preloadPopularity(for: ids)

            guard !Task.isCancelled else { return }

            let popularity = PersonPopularityStore.shared.popularitySnapshot()

            // 3) Final actor order (count, then popularity, then name) off-main.
            let sortedActors = await Task.detached(priority: .userInitiated) {
                StatsSnapshotBuilder.sortActors(
                    actors: base.actorsByCountRaw,
                    popularityByPersonId: popularity
                )
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
}
