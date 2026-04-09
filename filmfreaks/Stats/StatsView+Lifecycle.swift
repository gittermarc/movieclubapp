//
//  StatsView+Lifecycle.swift
//  filmfreaks
//
//  Centralized refresh and lightweight UI side effects for StatsView.
//

import Foundation

extension StatsView {

    var statsRefreshInputs: StatsViewModel.Inputs {
        StatsViewModel.Inputs(
            movies: movieStore.movies,
            users: userStore.users,
            ratingDisplayMode: displaySettings.ratingDisplayMode,
            selectedRange: selectedRange,
            selectedLocationFilter: selectedLocationFilter
        )
    }

    func refreshStatsSnapshot() {
        viewModel.update(statsRefreshInputs)
    }

    func handleSnapshotUpdate() {
        setGenreDisplayOrderNow()
    }

    func handleActorsDisclosureExpandedChange() {
        if !actorsDisclosureExpanded {
            showAllActors = false
        }
    }
}
