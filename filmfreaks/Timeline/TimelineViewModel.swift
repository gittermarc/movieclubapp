import Foundation
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {

    typealias SnapshotBuilder = (
        _ movies: [Movie],
        _ filterMode: TimelineFilterMode,
        _ selectedRange: TimelineTimeRange,
        _ selectedYear: Int,
        _ today: Date,
        _ calendar: Calendar
    ) -> TimelineSnapshot

    struct InputSignature: Equatable {
        let movies: [Movie]
        let filterMode: TimelineFilterMode
        let selectedRange: TimelineTimeRange
        let selectedYear: Int
        let currentDay: Date
    }

    @Published private(set) var filterMode: TimelineFilterMode
    @Published private(set) var selectedRange: TimelineTimeRange
    @Published private(set) var selectedYear: Int
    @Published private(set) var snapshot: TimelineSnapshot

    private let calendar: Calendar
    private let todayProvider: () -> Date
    private let snapshotBuilder: SnapshotBuilder

    private var movies: [Movie] = []
    private var lastInputSignature: InputSignature?

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
        let inputSignature = makeInputSignature()
        guard force || inputSignature != lastInputSignature else {
            return
        }

        let today = todayProvider()
        var nextSnapshot = buildSnapshot(selectedYear: selectedYear, today: today)
        var resolvedSelectedYear = selectedYear

        if filterMode == .year,
           !nextSnapshot.availableYears.contains(selectedYear),
           let firstYear = nextSnapshot.availableYears.first {
            resolvedSelectedYear = firstYear
            nextSnapshot = buildSnapshot(selectedYear: firstYear, today: today)
        }

        if resolvedSelectedYear != selectedYear {
            selectedYear = resolvedSelectedYear
        }

        snapshot = nextSnapshot
        lastInputSignature = InputSignature(
            movies: movies,
            filterMode: filterMode,
            selectedRange: selectedRange,
            selectedYear: selectedYear,
            currentDay: inputSignature.currentDay
        )
    }

    private func buildSnapshot(selectedYear: Int, today: Date) -> TimelineSnapshot {
        snapshotBuilder(
            movies,
            filterMode,
            selectedRange,
            selectedYear,
            today,
            calendar
        )
    }

    private func makeInputSignature() -> InputSignature {
        InputSignature(
            movies: movies,
            filterMode: filterMode,
            selectedRange: selectedRange,
            selectedYear: selectedYear,
            currentDay: calendar.startOfDay(for: todayProvider())
        )
    }
}
