//
//  ContentActivityPreviewModel.swift
//  filmfreaks
//
//  Created by Marc Fechner on 24.02.26.
//

internal import SwiftUI
import Combine

/// Computes the group activity preview items outside of the SwiftUI render path.
///
/// `ContentView.body` re-renders for many reasons (search text, filters, view style, etc.).
/// Building activity items is comparatively expensive (iterate movies + ratings + sort).
/// This model caches the result and only recomputes when the relevant inputs change.
@MainActor
final class ContentActivityPreviewModel: ObservableObject {

    typealias Snapshot = ContentActivityPreviewSnapshot
    typealias SnapshotBuilder = @Sendable (Inputs) -> Snapshot

    struct Inputs: Sendable {
        let watchedMovies: [Movie]
        let backlogMovies: [Movie]
        let movieNightEvents: [MovieNightActivityEvent]
        let ratingDisplayMode: RatingDisplayMode
    }

    @Published private(set) var items: [UnifiedGroupActivityEvent] = []
    @Published private(set) var allItems: [UnifiedGroupActivityEvent] = []

    private let snapshotBuilder: SnapshotBuilder

    private var updateTask: Task<Void, Never>?
    private var buildGeneration: Int = 0
    private var lastInputs: Inputs?

    init(snapshotBuilder: SnapshotBuilder? = nil) {
        self.snapshotBuilder = snapshotBuilder ?? { inputs in
            ContentActivityPreviewSnapshotBuilder.build(
                input: .init(
                    watchedMovies: inputs.watchedMovies,
                    backlogMovies: inputs.backlogMovies,
                    movieNightEvents: inputs.movieNightEvents,
                    ratingDisplayMode: inputs.ratingDisplayMode
                )
            )
        }
    }

    func update(
        movieStore: MovieStore,
        movieNightStore: MovieNightStore,
        currentGroupId: String,
        ratingDisplayMode: RatingDisplayMode
    ) {
        update(
            watchedMovies: movieStore.movies,
            backlogMovies: movieStore.backlogMovies,
            movieNightEvents: currentGroupId.isEmpty
                ? []
                : (movieNightStore.activityByGroup[currentGroupId] ?? []),
            ratingDisplayMode: ratingDisplayMode
        )
    }

    func update(
        watchedMovies: [Movie],
        backlogMovies: [Movie],
        movieNightEvents: [MovieNightActivityEvent],
        ratingDisplayMode: RatingDisplayMode
    ) {
        update(
            Inputs(
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies,
                movieNightEvents: movieNightEvents,
                ratingDisplayMode: ratingDisplayMode
            )
        )
    }

    func update(_ inputs: Inputs) {
        guard shouldScheduleUpdate(for: inputs) else { return }

        buildGeneration += 1
        let generation = buildGeneration
        let snapshotBuilder = self.snapshotBuilder

        updateTask?.cancel()
        updateTask = Task { [inputs, generation, snapshotBuilder] in
            guard !Task.isCancelled else { return }

            let snapshot = await Task.detached(priority: .userInitiated) {
                snapshotBuilder(inputs)
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.apply(snapshot: snapshot, for: generation)
            }
        }
    }

    private func shouldScheduleUpdate(for inputs: Inputs) -> Bool {
        if let lastInputs, inputs.isEquivalent(to: lastInputs) {
            return false
        }

        lastInputs = inputs
        return true
    }

    private func apply(snapshot: Snapshot, for generation: Int) {
        guard buildGeneration == generation else { return }
        items = snapshot.items
        allItems = snapshot.allItems
    }
}

private extension ContentActivityPreviewModel.Inputs {
    func isEquivalent(to other: Self) -> Bool {
        watchedMovies == other.watchedMovies
            && backlogMovies == other.backlogMovies
            && movieNightEvents == other.movieNightEvents
            && ratingDisplayMode.rawValue == other.ratingDisplayMode.rawValue
    }
}
