//
//  ContentView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct ContentView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var movieNightStore: MovieNightStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var groupStore: CloudKitGroupStore
    @EnvironmentObject var networkMonitor: NetworkMonitor
    @EnvironmentObject var displaySettings: DisplaySettings

    // MARK: - Routing (Sheets / Navigation)
    @State var route: ContentRoute? = nil

    // MARK: - Onboarding / Quick Start
    @AppStorage("Onboarding_HasSeenQuickStart") var hasSeenQuickStart: Bool = false
    @State private var onboardingChecklistExpanded: Bool = true

    @State var selectedMode: MovieListMode = .watched
    @State var filterByUser: User? = nil
    @State var selectedSort: MovieSortOption = .dateNewest

    // MARK: - Derived list/grid items (off render path)
    @StateObject var movieItemsModel = ContentMovieItemsModel()

    // MARK: - Activity preview (off render path)
    @StateObject var activityPreviewModel = ContentActivityPreviewModel()

    // MARK: - In-List Search (Watched/Backlog)
    @State var watchedSearchText: String = ""
    @State var backlogSearchText: String = ""
    @FocusState var listSearchIsFocused: Bool

    // MARK: - View Style
    @AppStorage("ContentView_ViewStyle") private var viewStyleRaw: String = MovieViewStyle.cards.rawValue

    
    // MARK: - UI Density Metrics
    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var currentGroupId: String {
        (movieStore.currentGroupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // NOTE: Activity preview is computed via `activityPreviewModel`.

    // MARK: - Onboarding (derived state)

    var onboarding: ContentOnboarding.State {
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

    // MARK: - Total count (stable, not filtered)

    private var selectedModeTotalCount: Int {
        switch selectedMode {
        case .watched:
            return movieStore.movies.count
        case .backlog:
            return movieStore.backlogMovies.count
        }
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



    // NOTE: Derived-state updates live in ContentView+DerivedState.swift.





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
        applyingLifecycleObservers(
            to: NavigationStack {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    VStack {
                        ContentHeaderView(
                            groupName: movieStore.currentGroupName,
                            totalMoviesInGroup: movieStore.movies.count + movieStore.backlogMovies.count,
                            activeListTotalCount: selectedModeTotalCount,
                            tintColor: displaySettings.tintColor,
                            activeMemberDisplayName: activeMemberDisplayName,
                            activeMemberInitials: activeMemberInitials,
                            hasActiveMemberSelected: hasActiveMemberSelected,
                            onTapGroup: { route = .groupSettings },
                            onTapActiveMember: { route = .users },
                            showGroupActivityCard: displaySettings.showGroupActivityCard,
                            activityPreviewItems: activityPreviewModel.items,
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
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(MovieStore.preview())
        .environmentObject(CloudKitGroupStore())
        .environmentObject(UserStore())
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(DisplaySettings())
}
