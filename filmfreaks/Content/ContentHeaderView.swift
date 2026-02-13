//
//  ContentHeaderView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Top-Sektion der ContentView (Gruppe/Onboarding/Controls/Sync-Zeile).
///
/// Ziel: ContentView als "Komposition" behalten und den Header als UI-Modul auslagern.
struct ContentHeaderView: View {

    // MARK: - Context Bar

    let groupName: String?
    let totalMoviesInGroup: Int
    let tintColor: Color

    let activeMemberDisplayName: String
    let activeMemberInitials: String
    let hasActiveMemberSelected: Bool

    let onTapGroup: () -> Void
    let onTapActiveMember: () -> Void

    // MARK: - Activity (Social)

    let showGroupActivityCard: Bool
    let activityPreviewItems: [UnifiedGroupActivityEvent]
    let onTapActivity: () -> Void

    // MARK: - Onboarding

    let shouldShowOnboardingChecklist: Bool
    @Binding var onboardingChecklistExpanded: Bool

    let onboardingStepsCompletedCount: Int
    let isGroupStepComplete: Bool
    let isMembersStepComplete: Bool
    let isFirstMovieStepComplete: Bool
    let isFirstRatingStepComplete: Bool
    let hasAnyMoviesInCurrentGroup: Bool

    let onTapOnboardingGroups: () -> Void
    let onTapOnboardingMembers: () -> Void
    let onTapOnboardingSearch: () -> Void

    // MARK: - Mode (Watched / Backlog)

    @Binding var selectedMode: MovieListMode
    let onModeChanged: () -> Void

    // MARK: - Controls

    let metrics: DisplaySettings.LayoutMetrics
    @Binding var selectedSort: MovieSortOption
    @Binding var filterByUser: User?
    let users: [User]
    let filterLabelText: String
    let filterHintText: String?
    @Binding var viewStyleRaw: String
    let selectedViewStyle: MovieViewStyle

    // MARK: - Sync

    let isConnected: Bool
    let isSyncing: Bool
    let pendingChangesCount: Int
    let lastError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let name = groupName {
                ContentContextBar(
                    groupName: name,
                    totalMoviesInGroup: totalMoviesInGroup,
                    tintColor: tintColor,
                    activeMemberDisplayName: activeMemberDisplayName,
                    activeMemberInitials: activeMemberInitials,
                    hasActiveMemberSelected: hasActiveMemberSelected,
                    onTapGroup: onTapGroup,
                    onTapActiveMember: onTapActiveMember
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)

                if showGroupActivityCard {
                    GroupActivityTeaserView(
                        events: activityPreviewItems,
                        onOpenAll: onTapActivity
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }

            if shouldShowOnboardingChecklist {
                ContentOnboardingChecklistView(
                    isExpanded: $onboardingChecklistExpanded,
                    stepsCompletedCount: onboardingStepsCompletedCount,
                    isGroupStepComplete: isGroupStepComplete,
                    isMembersStepComplete: isMembersStepComplete,
                    isFirstMovieStepComplete: isFirstMovieStepComplete,
                    isFirstRatingStepComplete: isFirstRatingStepComplete,
                    hasAnyMoviesInCurrentGroup: hasAnyMoviesInCurrentGroup,
                    onTapGroups: onTapOnboardingGroups,
                    onTapMembers: onTapOnboardingMembers,
                    onTapSearch: onTapOnboardingSearch
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Picker("Liste", selection: $selectedMode) {
                ForEach(MovieListMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .onChange(of: selectedMode) { _, _ in
                onModeChanged()
            }

            ContentControlsBarView(
                metrics: metrics,
                selectedSort: $selectedSort,
                filterByUser: $filterByUser,
                users: users,
                filterLabelText: filterLabelText,
                filterHintText: filterHintText,
                viewStyleRaw: $viewStyleRaw,
                selectedViewStyle: selectedViewStyle
            )
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 4)

            ContentSyncStatusLineView(
                isConnected: isConnected,
                isSyncing: isSyncing,
                pendingChangesCount: pendingChangesCount,
                lastError: lastError
            )
        }
    }
}
