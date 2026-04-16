import Foundation
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {

    typealias SnapshotBuilder = @Sendable (
        _ movies: [Movie],
        _ filterMode: TimelineFilterMode,
        _ selectedRange: TimelineTimeRange,
        _ selectedYear: Int,
        _ today: Date,
        _ calendar: Calendar
    ) -> TimelineSnapshot

    struct Inputs: Equatable, Sendable {
        let movies: [Movie]
        let filterMode: TimelineFilterMode
        let selectedRange: TimelineTimeRange
        let selectedYear: Int
        let currentDay: Date
    }

    struct BuildResult: Sendable {
        let snapshot: TimelineSnapshot
        let resolvedSelectedYear: Int
        let appliedInputs: Inputs
    }

    @Published private(set) var filterMode: TimelineFilterMode
    @Published private(set) var selectedRange: TimelineTimeRange
    @Published private(set) var selectedYear: Int
    @Published private(set) var snapshot: TimelineSnapshot

    private let calendar: Calendar
    private let todayProvider: () -> Date
    private let snapshotBuilder: SnapshotBuilder

    private var movies: [Movie] = []
    private var updateTask: Task<Void, Never>?
    private var buildGeneration: Int = 0
    private var lastScheduledInputs: Inputs?

    init(
        initialFilterMode: TimelineFilterMode = .year,
        initialSelectedRange: TimelineTimeRange = .thisYear,
        initialSelectedYear: Int? = nil,
        initialSnapshot: TimelineSnapshot? = nil,
        calendar: Calendar = .current,
        todayProvider: @escaping () -> Date = Date.init,
        snapshotBuilder: SnapshotBuilder? = nil
    ) {
        let resolvedYear = initialSelectedYear ?? calendar.component(.year, from: todayProvider())

        self.filterMode = initialFilterMode
        self.selectedRange = initialSelectedRange
        self.selectedYear = resolvedYear
        self.snapshot = initialSnapshot ?? TimelineSnapshot()
        self.calendar = calendar
        self.todayProvider = todayProvider
        self.snapshotBuilder = snapshotBuilder ?? { movies, filterMode, selectedRange, selectedYear, today, calendar in
            TimelineSnapshotBuilder.build(
                movies: movies,
                filterMode: filterMode,
                selectedRange: selectedRange,
                selectedYear: selectedYear,
                today: today,
                calendar: calendar
            )
        }
    }

    deinit {
        updateTask?.cancel()
    }

    func updateMovies(_ movies: [Movie]) {
        self.movies = movies
        rebuildSnapshotIfNeeded()
    }

    func setFilterMode(_ filterMode: TimelineFilterMode) {
        guard self.filterMode != filterMode else {
            return
        }

        self.filterMode = filterMode
        rebuildSnapshotIfNeeded(force: true)
    }

    func setSelectedRange(_ selectedRange: TimelineTimeRange) {
        guard self.selectedRange != selectedRange else {
            return
        }

        self.selectedRange = selectedRange
        rebuildSnapshotIfNeeded(force: true)
    }

    func setSelectedYear(_ selectedYear: Int) {
        guard self.selectedYear != selectedYear else {
            return
        }

        self.selectedYear = selectedYear
        rebuildSnapshotIfNeeded(force: true)
    }

    private func rebuildSnapshotIfNeeded(force: Bool = false) {
        let inputs = makeInputs()
        guard force || inputs != lastScheduledInputs else {
            return
        }

        lastScheduledInputs = inputs
        buildGeneration += 1

        let generation = buildGeneration
        let snapshotBuilder = self.snapshotBuilder
        let calendar = self.calendar

        updateTask?.cancel()
        updateTask = Task { [inputs, generation, snapshotBuilder, calendar] in
            guard !Task.isCancelled else { return }

            let result = await Task.detached(priority: .userInitiated) {
                Self.buildResult(
                    for: inputs,
                    calendar: calendar,
                    snapshotBuilder: snapshotBuilder
                )
            }.value

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.apply(result: result, for: generation)
            }
        }
    }

    private func apply(result: BuildResult, for generation: Int) {
        guard buildGeneration == generation else { return }

        if selectedYear != result.resolvedSelectedYear {
            selectedYear = result.resolvedSelectedYear
        }

        snapshot = result.snapshot
        lastScheduledInputs = result.appliedInputs
    }

    private func makeInputs() -> Inputs {
        Inputs(
            movies: movies,
            filterMode: filterMode,
            selectedRange: selectedRange,
            selectedYear: selectedYear,
            currentDay: calendar.startOfDay(for: todayProvider())
        )
    }

    nonisolated private static func buildResult(
        for inputs: Inputs,
        calendar: Calendar,
        snapshotBuilder: SnapshotBuilder
    ) -> BuildResult {
        var resolvedSelectedYear = inputs.selectedYear
        var snapshot = snapshotBuilder(
            inputs.movies,
            inputs.filterMode,
            inputs.selectedRange,
            inputs.selectedYear,
            inputs.currentDay,
            calendar
        )

        if inputs.filterMode == .year,
           !snapshot.availableYears.contains(inputs.selectedYear),
           let firstYear = snapshot.availableYears.first {
            resolvedSelectedYear = firstYear
            snapshot = snapshotBuilder(
                inputs.movies,
                inputs.filterMode,
                inputs.selectedRange,
                firstYear,
                inputs.currentDay,
                calendar
            )
        }

        return BuildResult(
            snapshot: snapshot,
            resolvedSelectedYear: resolvedSelectedYear,
            appliedInputs: Inputs(
                movies: inputs.movies,
                filterMode: inputs.filterMode,
                selectedRange: inputs.selectedRange,
                selectedYear: resolvedSelectedYear,
                currentDay: inputs.currentDay
            )
        )
    }
}
