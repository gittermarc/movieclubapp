//
//  ContentView+DerivedState.swift
//  filmfreaks
//
//  Extracted from ContentView to keep derived-state refresh logic focused and easier to maintain.
//

internal import SwiftUI

extension ContentView {

    // MARK: - Derived-State Refresh

    @MainActor
    func updateMovieItemsModel() {
        movieItemsModel.update(
            watchedMovies: movieStore.movies,
            backlogMovies: movieStore.backlogMovies,
            watchedSearchText: watchedSearchText,
            backlogSearchText: backlogSearchText,
            filterByUser: filterByUser,
            sort: selectedSort,
            ratingDisplayMode: displaySettings.ratingDisplayMode,
            showTMDbRatingsInLists: displaySettings.showTMDbRatingsInLists
        )
    }

    @MainActor
    func updateActivityPreviewModel() {
        activityPreviewModel.update(
            movieStore: movieStore,
            movieNightStore: movieNightStore,
            currentGroupId: currentGroupId,
            ratingDisplayMode: displaySettings.ratingDisplayMode
        )
    }
}
