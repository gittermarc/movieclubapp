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

    var filterModeBinding: Binding<TimelineFilterMode> {
        Binding(
            get: { viewModel.filterMode },
            set: { viewModel.setFilterMode($0) }
        )
    }

    var selectedRangeBinding: Binding<TimelineTimeRange> {
        Binding(
            get: { viewModel.selectedRange },
            set: { viewModel.setSelectedRange($0) }
        )
    }

    var selectedYearBinding: Binding<Int> {
        Binding(
            get: { viewModel.selectedYear },
            set: { viewModel.setSelectedYear($0) }
        )
    }

    func binding(for movie: Movie) -> Binding<Movie>? {
        guard let idx = movieStore.movies.firstIndex(where: { $0.id == movie.id }) else {
            return nil
        }
        return $movieStore.movies[idx]
    }
}
