//
//  ContentView+Lifecycle.swift
//  filmfreaks
//
//  Extracted from ContentView to keep trigger and lifecycle wiring out of the main view file.
//

internal import SwiftUI

extension ContentView {

    // MARK: - Lifecycle / Trigger Wiring

    func applyingLifecycleObservers<Root: View>(to root: Root) -> some View {
        root
            .onAppear {
                handleInitialAppearance()
            }
            .onReceive(movieStore.$movies) { _ in
                handleMovieLibraryChanged()
            }
            .onReceive(movieStore.$backlogMovies) { _ in
                handleBacklogLibraryChanged()
            }
            .onReceive(movieNightStore.$activityByGroup) { _ in
                handleMovieNightActivityChanged()
            }
            .onChange(of: watchedSearchText) { _, _ in
                handleMovieItemsInputsChanged()
            }
            .onChange(of: backlogSearchText) { _, _ in
                handleMovieItemsInputsChanged()
            }
            .onChange(of: filterByUser?.id) { _, _ in
                handleMovieItemsInputsChanged()
            }
            .onChange(of: selectedSort) { _, _ in
                handleMovieItemsInputsChanged()
            }
            .onReceive(displaySettings.$ratingDisplayMode) { _ in
                handleRatingDisplayModeChanged()
            }
            .onReceive(displaySettings.$showTMDbRatingsInLists) { _ in
                handleRatingSourceVisibilityChanged()
            }
            .onChange(of: movieStore.currentGroupId) { _, _ in
                handleCurrentGroupChanged()
            }
            .onChange(of: movieStore.currentGroupName) { _, _ in
                handleOnboardingInputsChanged()
            }
            .onChange(of: movieStore.movies.count) { _, _ in
                handleOnboardingInputsChanged()
            }
            .onChange(of: movieStore.backlogMovies.count) { _, _ in
                handleOnboardingInputsChanged()
            }
            .onChange(of: userStore.users.count) { _, _ in
                handleOnboardingInputsChanged()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pushDeepLinkRequested)) { note in
                handlePushDeepLink(note.userInfo)
            }
    }

    // MARK: - Trigger Handlers

    func handleInitialAppearance() {
        if !hasSeenQuickStart {
            route = .quickStart
        }
        updateOnboardingCompletionFlag()
        scheduleMovieItemsRefresh()
        scheduleActivityPreviewRefresh()
    }

    func handleMovieLibraryChanged() {
        scheduleMovieItemsRefresh()
        scheduleActivityPreviewRefresh()
    }

    func handleBacklogLibraryChanged() {
        scheduleMovieItemsRefresh()
        scheduleActivityPreviewRefresh()
    }

    func handleMovieNightActivityChanged() {
        scheduleActivityPreviewRefresh()
    }

    func handleMovieItemsInputsChanged() {
        scheduleMovieItemsRefresh()
    }

    func handleRatingDisplayModeChanged() {
        scheduleMovieItemsRefresh()
        scheduleActivityPreviewRefresh()
    }

    func handleRatingSourceVisibilityChanged() {
        scheduleMovieItemsRefresh()
    }

    func handleCurrentGroupChanged() {
        updateOnboardingCompletionFlag()
        scheduleActivityPreviewRefresh()
    }

    func handleOnboardingInputsChanged() {
        updateOnboardingCompletionFlag()
    }

    private func scheduleMovieItemsRefresh() {
        let coordinator = movieItemsRefreshCoordinator
        let model = movieItemsModel
        let watchedMovies = movieStore.movies
        let backlogMovies = movieStore.backlogMovies
        let watchedSearchText = watchedSearchText
        let backlogSearchText = backlogSearchText
        let filterByUser = filterByUser
        let selectedSort = selectedSort
        let ratingDisplayMode = displaySettings.ratingDisplayMode
        let showTMDbRatingsInLists = displaySettings.showTMDbRatingsInLists

        coordinator.triggerRefresh(debounceSeconds: 0) {
            model.update(
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies,
                watchedSearchText: watchedSearchText,
                backlogSearchText: backlogSearchText,
                filterByUser: filterByUser,
                sort: selectedSort,
                ratingDisplayMode: ratingDisplayMode,
                showTMDbRatingsInLists: showTMDbRatingsInLists
            )
        }
    }

    private func scheduleActivityPreviewRefresh() {
        let coordinator = activityPreviewRefreshCoordinator
        let model = activityPreviewModel
        let watchedMovies = movieStore.movies
        let backlogMovies = movieStore.backlogMovies
        let movieNightEvents = currentGroupId.isEmpty
            ? []
            : (movieNightStore.activityByGroup[currentGroupId] ?? [])
        let ratingDisplayMode = displaySettings.ratingDisplayMode

        coordinator.triggerRefresh(debounceSeconds: 0) {
            model.update(
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies,
                movieNightEvents: movieNightEvents,
                ratingDisplayMode: ratingDisplayMode
            )
        }
    }
}
