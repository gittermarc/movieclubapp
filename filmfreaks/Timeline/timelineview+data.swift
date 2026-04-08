//
//  timelineview+data.swift
//  filmfreaks
//

internal import SwiftUI

extension TimelineView {

    var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "LLLL yyyy"
        return df
    }

    func updateSnapshot() {
        var nextSnapshot = TimelineSnapshotBuilder.build(
            movies: movieStore.movies,
            filterMode: filterMode,
            selectedRange: selectedRange,
            selectedYear: selectedYear
        )

        if filterMode == .year, !nextSnapshot.availableYears.contains(selectedYear), let firstYear = nextSnapshot.availableYears.first {
            selectedYear = firstYear
            nextSnapshot = TimelineSnapshotBuilder.build(
                movies: movieStore.movies,
                filterMode: filterMode,
                selectedRange: selectedRange,
                selectedYear: firstYear
            )
        }

        snapshot = nextSnapshot
    }

    func binding(for movie: Movie) -> Binding<Movie>? {
        guard let idx = movieStore.movies.firstIndex(where: { $0.id == movie.id }) else {
            return nil
        }
        return $movieStore.movies[idx]
    }
}
