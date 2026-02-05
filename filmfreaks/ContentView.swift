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
    private var g: DisplaySettings.PosterGridMetrics { displaySettings.posterGridMetrics }

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

                    // MARK: - Inhalt: entweder Empty State oder Listen
                    if hasAnyMoviesInCurrentGroup {

                        switch selectedViewStyle {
                        case .posterGrid:
                            ScrollView {
                                switch selectedMode {
                                case .watched:
                                    posterGrid(items: watchedGridItems, isBacklog: false)
                                case .backlog:
                                    posterGrid(items: backlogGridItems, isBacklog: true)
                                }
                            }
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                if shouldShowListSearchBar {
                                    InListSearchBar(
                                        placeholder: listSearchPlaceholder,
                                        text: activeListSearchText,
                                        isFocused: $listSearchIsFocused,
                                        metrics: m
                                    )
                                }
                            }
                            .refreshable {
                                await performPullToRefresh()
                            }

                        case .cards, .compactList:
                            // Normale Listen
                            List {
                                switch selectedMode {
                                case .watched:
                                    ContentMoviesListSection(
                                        items: watchedListItems,
                                        movies: $movieStore.movies,
                                        isBacklog: false,
                                        selectedViewStyle: selectedViewStyle,
                                        query: watchedSearchText,
                                        displayScore: displayScore
                                    )
                                case .backlog:
                                    ContentMoviesListSection(
                                        items: backlogListItems,
                                        movies: $movieStore.backlogMovies,
                                        isBacklog: true,
                                        selectedViewStyle: selectedViewStyle,
                                        query: backlogSearchText,
                                        displayScore: displayScore
                                    )
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .listStyle(.plain)
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                if shouldShowListSearchBar {
                                    InListSearchBar(
                                        placeholder: listSearchPlaceholder,
                                        text: activeListSearchText,
                                        isFocused: $listSearchIsFocused,
                                        metrics: m
                                    )
                                }
                            }
                            .refreshable {
                                await performPullToRefresh()
                            }
                        }
                    } else {
                        // Empty State: trotzdem pull-to-refresh ermöglichen
                        ScrollView {
                            emptyStateView
                                .padding(.horizontal, 24)
                                .padding(.top, 32)
                            Spacer(minLength: 0)
                        }
                        .refreshable {
                            await performPullToRefresh()
                        }
                    }
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

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "popcorn")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Noch keine Filme in dieser Gruppe")
                .font(.headline)

            Text("Suche nach einem Film auf TMDb und füge ihn deiner „Gesehen“-Liste oder deinem Backlog hinzu.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                trackSearchOpened()
	                route = .movieSearch
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Film suchen")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            HStack(spacing: 12) {
                Button {
	                    route = .users
                } label: {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Mitglieder hinzufügen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
	                    route = .groupSettings
                } label: {
                    HStack {
                        Image(systemName: "person.3.sequence")
                        Text("Gruppen verwalten")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Grid-Ansicht (Cover-Only)

    @ViewBuilder
    private func posterGrid(items: [IndexedMovie], isBacklog: Bool) -> some View {
        let query = (isBacklog ? backlogSearchText : watchedSearchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if items.isEmpty {
            if !query.isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        "Keine Treffer",
                        systemImage: "magnifyingglass",
                        description: Text("Passe den Suchbegriff an oder lösche ihn.")
                    )

                    Button("Suche zurücksetzen") {
                        if isBacklog {
                            backlogSearchText = ""
                        } else {
                            watchedSearchText = ""
                        }
                        listSearchIsFocused = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 32)
                .padding(.horizontal)
            } else {
                ContentUnavailableView(
                    "Keine Filme",
                    systemImage: "film",
                    description: Text("In dieser Ansicht gibt's gerade nichts anzuzeigen.")
                )
                .padding(.top, 32)
                .padding(.horizontal)
            }
        } else {
            let columns = [GridItem(.adaptive(minimum: g.minColumnWidth), spacing: g.spacing)]

            LazyVGrid(columns: columns, spacing: g.spacing) {
                ForEach(items) { item in
                    // When switching groups, SwiftUI can briefly render stale `items`.
                    // Guard indices to prevent out-of-range crashes.
                    if isBacklog {
                        if movieStore.backlogMovies.indices.contains(item.index) {
                            let movie = movieStore.backlogMovies[item.index]
                            NavigationLink {
                                MovieDetailView(
                                    movie: $movieStore.backlogMovies[item.index],
                                    isBacklog: true
                                )
                            } label: {
                                ContentPosterGridCellView(movie: movie)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    guard movieStore.backlogMovies.indices.contains(item.index) else { return }
                                    movieStore.backlogMovies.remove(at: item.index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    } else {
                        if movieStore.movies.indices.contains(item.index) {
                            let movie = movieStore.movies[item.index]
                            NavigationLink {
                                MovieDetailView(
                                    movie: $movieStore.movies[item.index],
                                    isBacklog: false
                                )
                            } label: {
                                ContentPosterGridCellView(movie: movie)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    guard movieStore.movies.indices.contains(item.index) else { return }
                                    movieStore.movies.remove(at: item.index)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
    }

}

#Preview {
    ContentView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(DisplaySettings())
}
