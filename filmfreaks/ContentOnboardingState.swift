//
//  ContentOnboardingState.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

import Foundation

/// Encapsulates the onboarding logic that used to live inside `ContentView`.
///
/// Goal: keep `ContentView` as composition-only and centralize onboarding rules
/// in one place (state calculation + tracking / persistence).
enum ContentOnboarding {

    struct State: Equatable {
        let groupIdForProgress: String?

        let hasAnyMoviesInCurrentGroup: Bool

        let isGroupStepComplete: Bool
        let isMembersStepComplete: Bool
        let isFirstMovieStepComplete: Bool
        let isFirstRatingStepComplete: Bool

        let stepsCompletedCount: Int
        let isCompletedNow: Bool

        let shouldShowChecklist: Bool
    }

    @MainActor
    static func makeState(movieStore: MovieStore, userStore: UserStore) -> State {
        let groupIdForProgress = movieStore.currentGroupId
        let hasAnyMoviesInCurrentGroup = !movieStore.movies.isEmpty || !movieStore.backlogMovies.isEmpty

        // ✅ Gruppe gilt als "erledigt", sobald man faktisch in einer Gruppe arbeitet.
        // (z.B. schon Filme vorhanden, Name gesetzt, Gruppe gewechselt, bekannte Gruppen vorhanden)
        let trimmedGroupName = movieStore.currentGroupName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isGroupStepComplete = hasAnyMoviesInCurrentGroup
        || (trimmedGroupName?.isEmpty == false)
        || (movieStore.currentGroupId != nil)
        || (!movieStore.knownGroups.isEmpty)

        let isMembersStepComplete = !userStore.users.isEmpty
        let isFirstMovieStepComplete = hasAnyMoviesInCurrentGroup
        let isFirstRatingStepComplete = movieStore.movies.contains { !$0.ratings.isEmpty }

        let stepsCompletedCount = [
            isGroupStepComplete,
            isMembersStepComplete,
            isFirstMovieStepComplete,
            isFirstRatingStepComplete
        ]
            .filter { $0 }
            .count

        let isCompletedNow = (stepsCompletedCount == 4)

        // Persisted completion beats current state
        let isPersistedComplete = OnboardingProgress.isGroupOnboardingComplete(forGroupId: groupIdForProgress)
        let shouldShowChecklist = (!isPersistedComplete) && (!isCompletedNow)

        return State(
            groupIdForProgress: groupIdForProgress,
            hasAnyMoviesInCurrentGroup: hasAnyMoviesInCurrentGroup,
            isGroupStepComplete: isGroupStepComplete,
            isMembersStepComplete: isMembersStepComplete,
            isFirstMovieStepComplete: isFirstMovieStepComplete,
            isFirstRatingStepComplete: isFirstRatingStepComplete,
            stepsCompletedCount: stepsCompletedCount,
            isCompletedNow: isCompletedNow,
            shouldShowChecklist: shouldShowChecklist
        )
    }

    /// Persists onboarding completion for the given state (idempotent).
    static func updateCompletionFlagIfNeeded(for state: State) {
        guard state.isCompletedNow else { return }
        OnboardingProgress.setGroupOnboardingComplete(true, forGroupId: state.groupIdForProgress)
    }

    static func trackSearchOpened(forGroupId groupId: String?) {
        OnboardingProgress.incrementSearchOpenCount(forGroupId: groupId)
    }
}
