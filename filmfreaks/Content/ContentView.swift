//
//  ContentView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct ContentView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var displaySettings: DisplaySettings

    // MARK: - Routing (Sheets / Navigation)
    @State private var route: ContentRoute? = nil

    // MARK: - Onboarding / Quick Start
    @AppStorage("Onboarding_HasSeenQuickStart") private var hasSeenQuickStart: Bool = false
    @State private var onboardingChecklistExpanded: Bool = true

    @State var selectedMode: MovieListMode = .watched
    @State var filterByUser: User? = nil
    @State var selectedSort: MovieSortOption = .dateNewest

    // MARK: - In-List Search (Watched/Backlog)
    @State var watchedSearchText: String = ""
    @State var backlogSearchText: String = ""
    @FocusState var listSearchIsFocused: Bool

    // MARK: - View Style
    @AppStorage("ContentView_ViewStyle") private var viewStyleRaw: String = MovieViewStyle.cards.rawValue

    
    // MARK: - UI Density Metrics
    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    private var activityPreviewEvents: [GroupActivityEvent] {
        movieStore.activityEvents(displayMode: displaySettings.ratingDisplayMode, limit: 3)
    }

    // MARK: - Onboarding (derived state)

    private var onboarding: ContentOnboarding.State {
        ContentOnboarding.makeState(movieStore: movieStore, userStore: userStore)
    }


    /// Gibt an, ob es in der aktuellen Gruppe überhaupt schon Filme gibt
    private var hasAnyMoviesInCurrentGroup: Bool {
        onboarding.hasAnyMoviesInCurrentGroup
    }

    private var shouldShowListSearchBar: Bool {
        guard hasAnyMoviesInCurrentGroup else { return false }
        switch selectedMode {
        case .watched:
            return !movieStore.movies.isEmpty
        case .backlog:
            return !movieStore.backlogMovies.isEmpty
        }
    }

    private var listSearchPlaceholder: String {
        "In \(selectedMode.rawValue) suchen"
    }

    private var activeListSearchText: Binding<String> {
        Binding(
            get: {
                switch selectedMode {
                case .watched: return watchedSearchText
                case .backlog: return backlogSearchText
                }
            },
            set: { newValue in
                switch selectedMode {
                case .watched: watchedSearchText = newValue
                case .backlog: backlogSearchText = newValue
                }
            }
        )
    }

    private var filterLabelText: String {
        filterByUser?.name ?? "Alle"
    }

    private var filterHintText: String? {
        guard filterByUser != nil else { return nil }
        if selectedMode == .watched {
            return "Filter zeigt nur Filme, in denen diese Person bewertet hat."
        } else {
            return "Filter zeigt nur Filme, die von dieser Person vorgeschlagen wurden."
        }
    }

    private var selectedViewStyle: MovieViewStyle {
        MovieViewStyle(rawValue: viewStyleRaw) ?? .cards
    }

    // MARK: - Rating display helper

    /// Einheitliche Kennzahl für Anzeige/Sortierung (abhängig von Einstellungen).
    /// Fällt auf TMDb zurück, wenn die Gruppe noch nichts bewertet hat.
    func displayScore(for movie: Movie) -> Double? {
        if displaySettings.showTMDbRatingsInLists {
            return movie.displayAverage(for: displaySettings.ratingDisplayMode)
        } else {
            // Kein TMDb-Fallback: in Listen nur echte Gruppenwerte anzeigen.
            return movie.groupAverage(for: displaySettings.ratingDisplayMode)
        }
    }




    // MARK: - Aktives Mitglied (rechts neben der Gruppe)

    private var hasActiveMemberSelected: Bool {
        userStore.selectedUser != nil
    }

    private var activeMemberDisplayName: String {
        guard let raw = userStore.selectedUser?.name else { return "Keins gewählt" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Keins gewählt" : trimmed
    }

    private var activeMemberInitials: String {
        guard hasActiveMemberSelected else { return "–" }
        return initials(from: activeMemberDisplayName)
    }

    private func initials(from name: String) -> String {
        let parts = name
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" })
            .map { String($0) }
            .filter { !$0.isEmpty }

        if parts.isEmpty { return "?" }
        if parts.count == 1 {
            return String(parts[0].prefix(2)).uppercased()
        }
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.last?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack {
                    ContentHeaderView(
                        groupName: movieStore.currentGroupName,
                        totalMoviesInGroup: movieStore.movies.count + movieStore.backlogMovies.count,
                        tintColor: displaySettings.tintColor,
                        activeMemberDisplayName: activeMemberDisplayName,
                        activeMemberInitials: activeMemberInitials,
                        hasActiveMemberSelected: hasActiveMemberSelected,
                        onTapGroup: { route = .groupSettings },
                        onTapActiveMember: { route = .users },
                        showGroupActivityCard: displaySettings.showGroupActivityCard,
                        activityPreviewEvents: activityPreviewEvents,
                        onTapActivity: { route = .activity },
                        shouldShowOnboardingChecklist: onboarding.shouldShowChecklist,
                        onboardingChecklistExpanded: $onboardingChecklistExpanded,
                        onboardingStepsCompletedCount: onboarding.stepsCompletedCount,
                        isGroupStepComplete: onboarding.isGroupStepComplete,
                        isMembersStepComplete: onboarding.isMembersStepComplete,
                        isFirstMovieStepComplete: onboarding.isFirstMovieStepComplete,
                        isFirstRatingStepComplete: onboarding.isFirstRatingStepComplete,
                        hasAnyMoviesInCurrentGroup: hasAnyMoviesInCurrentGroup,
                        onTapOnboardingGroups: { route = .groupSettings },
                        onTapOnboardingMembers: { route = .users },
                        onTapOnboardingSearch: {
                            trackSearchOpened()
                            route = .movieSearch
                        },
                        selectedMode: $selectedMode,
                        onModeChanged: {
                            listSearchIsFocused = false
                        },
                        metrics: m,
                        selectedSort: $selectedSort,
                        filterByUser: $filterByUser,
                        users: userStore.users,
                        filterLabelText: filterLabelText,
                        filterHintText: filterHintText,
                        viewStyleRaw: $viewStyleRaw,
                        selectedViewStyle: selectedViewStyle,
                        isConnected: networkMonitor.isConnected,
                        isSyncing: movieStore.isSyncing || userStore.isSyncing,
                        pendingChangesCount: movieStore.pendingCloudChangesCount,
                        lastError: movieStore.lastCloudSyncError
                    )

                    ContentMainAreaView(
                        hasAnyMoviesInCurrentGroup: hasAnyMoviesInCurrentGroup,
                        selectedMode: $selectedMode,
                        selectedViewStyle: selectedViewStyle,
                        watchedListItems: watchedListItems,
                        backlogListItems: backlogListItems,
                        watchedGridItems: watchedGridItems,
                        backlogGridItems: backlogGridItems,
                        watchedSearchText: $watchedSearchText,
                        backlogSearchText: $backlogSearchText,
                        shouldShowListSearchBar: shouldShowListSearchBar,
                        listSearchPlaceholder: listSearchPlaceholder,
                        activeListSearchText: activeListSearchText,
                        listSearchIsFocused: $listSearchIsFocused,
                        metrics: m,
                        displayScore: { movie in
                            displayScore(for: movie)
                        },
                        onRefresh: {
                            await performPullToRefresh()
                        },
                        onOpenSearch: {
                            trackSearchOpened()
                            route = .movieSearch
                        },
                        onOpenUsers: {
                            route = .users
                        },
                        onOpenGroupSettings: {
                            route = .groupSettings
                        }
                    )


                }

            }
            .navigationTitle("The Movie Club")
            .onAppear {
                // Quick Start nur beim ersten Start – danach nicht mehr.
                if !hasSeenQuickStart {
	                    route = .quickStart
                }
                updateOnboardingCompletionFlag()
            }
            .onChange(of: movieStore.currentGroupId) { _, _ in
                updateOnboardingCompletionFlag()
            }
            .onChange(of: movieStore.currentGroupName) { _, _ in
                updateOnboardingCompletionFlag()
            }
            .onChange(of: movieStore.movies.count) { _, _ in
                updateOnboardingCompletionFlag()
            }
            .onChange(of: movieStore.backlogMovies.count) { _, _ in
                updateOnboardingCompletionFlag()
            }
            .onChange(of: userStore.users.count) { _, _ in
                updateOnboardingCompletionFlag()
            }

            .toolbar {
                ContentToolbar(
                    route: $route,
                    trackSearchOpened: trackSearchOpened
                )
            }
            .contentRouting(
                route: $route,
                hasSeenQuickStart: $hasSeenQuickStart,
                trackSearchOpened: trackSearchOpened
            )
        }
    }

    // MARK: - Onboarding Tracking

    private func updateOnboardingCompletionFlag() {
        ContentOnboarding.updateCompletionFlagIfNeeded(for: onboarding)
    }

    private func trackSearchOpened() {
        ContentOnboarding.trackSearchOpened(forGroupId: onboarding.groupIdForProgress)
    }

    
}

#Preview {
    ContentView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(DisplaySettings())
}
