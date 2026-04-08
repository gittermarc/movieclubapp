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
        updateMovieItemsModel()
        updateActivityPreviewModel()
    }

    func handleMovieLibraryChanged() {
        updateMovieItemsModel()
        updateActivityPreviewModel()
    }

    func handleBacklogLibraryChanged() {
        updateMovieItemsModel()
        updateActivityPreviewModel()
    }

    func handleMovieNightActivityChanged() {
        updateActivityPreviewModel()
    }

    func handleMovieItemsInputsChanged() {
        updateMovieItemsModel()
    }

    func handleRatingDisplayModeChanged() {
        updateMovieItemsModel()
        updateActivityPreviewModel()
    }

    func handleRatingSourceVisibilityChanged() {
        updateMovieItemsModel()
    }

    func handleCurrentGroupChanged() {
        updateOnboardingCompletionFlag()
        updateActivityPreviewModel()
    }

    func handleOnboardingInputsChanged() {
        updateOnboardingCompletionFlag()
    }
}
