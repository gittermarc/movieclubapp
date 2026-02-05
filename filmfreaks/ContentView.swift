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

    @State private var selectedMode: MovieListMode = .watched
    @State private var filterByUser: User? = nil
    @State private var selectedSort: MovieSortOption = .dateNewest

    // MARK: - In-List Search (Watched/Backlog)
    @State private var watchedSearchText: String = ""
    @State private var backlogSearchText: String = ""
    @FocusState private var listSearchIsFocused: Bool

    // MARK: - View Style
    @AppStorage("ContentView_ViewStyle") private var viewStyleRaw: String = MovieViewStyle.cards.rawValue

    
    // MARK: - UI Density Metrics
    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }
    private var g: DisplaySettings.PosterGridMetrics { displaySettings.posterGridMetrics }


    /// Gibt an, ob es in der aktuellen Gruppe überhaupt schon Filme gibt
    private var hasAnyMoviesInCurrentGroup: Bool {
        !movieStore.movies.isEmpty || !movieStore.backlogMovies.isEmpty
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
    private func displayScore(for movie: Movie) -> Double? {
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
                        shouldShowOnboardingChecklist: shouldShowOnboardingChecklist,
                        onboardingChecklistExpanded: $onboardingChecklistExpanded,
                        onboardingStepsCompletedCount: onboardingStepsCompletedCount,
                        isGroupStepComplete: isGroupStepComplete,
                        isMembersStepComplete: isMembersStepComplete,
                        isFirstMovieStepComplete: isFirstMovieStepComplete,
                        isFirstRatingStepComplete: isFirstRatingStepComplete,
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
                                    watchedList
                                case .backlog:
                                    backlogList
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
                // Wichtigste Aktion als Quick-Button – bleibt immer erreichbar.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
	                            route = .users
                        } label: {
                            Label("Mitglieder", systemImage: "person.3")
                        }

                        Button {
	                            route = .groupSettings
                        } label: {
                            Label("Gruppen", systemImage: "person.3.sequence")
                        }

                        Divider()

                        Button {
	                            route = .stats
                        } label: {
                            Label("Statistiken", systemImage: "chart.bar.fill")
                        }

                        Button {
	                            route = .timeline
                        } label: {
                            Label("Timeline", systemImage: "rectangle.stack.fill")
                        }

                        Button {
	                            route = .goals
                        } label: {
                            Label("Ziele", systemImage: "target")
                        }

                        Divider()

                        Button {
	                            route = .settings
                        } label: {
                            Label("Einstellungen", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Mehr")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        trackSearchOpened()
	                        route = .movieSearch
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Film suchen")
                }
	            }
	            .contentRouting(
	                route: $route,
	                hasSeenQuickStart: $hasSeenQuickStart,
	                trackSearchOpened: trackSearchOpened
	            )
        }
    }

    // MARK: - Onboarding State

    private var onboardingGroupIdForProgress: String? {
        // Für die Standard-Gruppe ist currentGroupId nil → wir speichern dann unter "Default"
        movieStore.currentGroupId
    }

    private var isGroupStepComplete: Bool {
        // Wenn es schon Filme gibt, ist "Gruppe" de-facto erfüllt (auch ohne Invite-Code).
        if hasAnyMoviesInCurrentGroup { return true }
        if let name = movieStore.currentGroupName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if movieStore.currentGroupId != nil { return true }
        if !movieStore.knownGroups.isEmpty { return true }
        return false
    }

    private var isMembersStepComplete: Bool {
        !userStore.users.isEmpty
    }

    private var isFirstMovieStepComplete: Bool {
        hasAnyMoviesInCurrentGroup
    }

    private var isFirstRatingStepComplete: Bool {
        movieStore.movies.contains { !$0.ratings.isEmpty }
    }

    private var onboardingStepsCompletedCount: Int {
        [isGroupStepComplete, isMembersStepComplete, isFirstMovieStepComplete, isFirstRatingStepComplete]
            .filter { $0 }
            .count
    }

    private var isOnboardingCompletedNow: Bool {
        onboardingStepsCompletedCount == 4
    }

    private var shouldShowOnboardingChecklist: Bool {
        if OnboardingProgress.isGroupOnboardingComplete(forGroupId: onboardingGroupIdForProgress) {
            return false
        }
        return !isOnboardingCompletedNow
    }

    private func updateOnboardingCompletionFlag() {
        if isOnboardingCompletedNow {
            OnboardingProgress.setGroupOnboardingComplete(true, forGroupId: onboardingGroupIdForProgress)
        }
    }

    private func trackSearchOpened() {
        OnboardingProgress.incrementSearchOpenCount(forGroupId: onboardingGroupIdForProgress)
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

    // MARK: - Filter-Helfer

    /// Filter-Logik für watched-Liste: nach Bewertungen des Users
    private func passesUserFilterForWatched(_ movie: Movie) -> Bool {
        guard let user = filterByUser else {
            return true
        }
        return movie.ratings.contains { rating in
            if let rid = rating.reviewerId {
                return rid == user.id
            }
            // Legacy/local fallback: compare by display name
            return rating.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(user.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    /// Filter-Logik für Backlog: nach „Vorgeschlagen von“
    private func passesUserFilterForBacklog(_ movie: Movie) -> Bool {
        guard let user = filterByUser else {
            return true
        }
        guard let sugg = movie.suggestedBy else { return false }
        return sugg.lowercased() == user.name.lowercased()
    }

    // MARK: - In-List Search (Textfilter)

    private func normalizedSearchString(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    /// Freitext-Suche innerhalb der Liste (Titel/Jahr/Location/SuggestedBy + optional Cast/Genres/Keywords).
    /// Token-basiert: alle Wörter müssen vorkommen ("ring 2001" findet auch "Herr der Ringe (2001)").
    private func passesListSearch(_ movie: Movie, isBacklog: Bool) -> Bool {
        let raw = (isBacklog ? backlogSearchText : watchedSearchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !raw.isEmpty else { return true }

        let tokens = normalizedSearchString(raw)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return true }

        var fields: [String] = [movie.title, movie.year]

        if let location = movie.watchedLocation, !location.isEmpty {
            fields.append(location)
        }

        if let suggestedBy = movie.suggestedBy, !suggestedBy.isEmpty {
            fields.append(suggestedBy)
        }

        if let cast = movie.cast, !cast.isEmpty {
            fields.append(cast.map { $0.name }.joined(separator: " "))
        }

        if let directors = movie.directors, !directors.isEmpty {
            fields.append(directors.map { $0.name }.joined(separator: " "))
        }

        if let genres = movie.genres, !genres.isEmpty {
            fields.append(genres.joined(separator: " "))
        }

        if let keywords = movie.keywords, !keywords.isEmpty {
            fields.append(keywords.joined(separator: " "))
        }

        let haystack = normalizedSearchString(fields.joined(separator: " "))
        return tokens.allSatisfy { haystack.contains($0) }
    }



    // MARK: - Grid-Daten (gefiltert + sortiert)

    private struct GridMovieItem: Identifiable {
        let index: Int
        let movie: Movie
        var id: String { String(describing: movie.id) }
    }

    private var watchedGridItems: [GridMovieItem] {
        let enumerated = Array(movieStore.movies.enumerated())
            .filter { _, movie in
                passesUserFilterForWatched(movie) && passesListSearch(movie, isBacklog: false)
            }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = displayScore(for: lhsMovie) ?? -Double.infinity
                let r = displayScore(for: rhsMovie) ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = displayScore(for: lhsMovie) ?? Double.infinity
                let r = displayScore(for: rhsMovie) ?? Double.infinity
                return l < r
            case .dateNewest:
                let l = lhsMovie.watchedDate ?? .distantPast
                let r = rhsMovie.watchedDate ?? .distantPast
                return l > r
            case .dateOldest:
                let l = lhsMovie.watchedDate ?? .distantFuture
                let r = rhsMovie.watchedDate ?? .distantFuture
                return l < r
            }
        }

        return sorted.map { GridMovieItem(index: $0.offset, movie: $0.element) }
    }

    private var backlogGridItems: [GridMovieItem] {
        let enumerated = Array(movieStore.backlogMovies.enumerated())
            .filter { _, movie in
                passesUserFilterForBacklog(movie) && passesListSearch(movie, isBacklog: true)
            }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = displayScore(for: lhsMovie) ?? -Double.infinity
                let r = displayScore(for: rhsMovie) ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = displayScore(for: lhsMovie) ?? Double.infinity
                let r = displayScore(for: rhsMovie) ?? Double.infinity
                return l < r
            case .dateNewest:
                // Im Backlog: neuestes Erscheinungsjahr zuerst
                return lhsMovie.year > rhsMovie.year
            case .dateOldest:
                // Im Backlog: ältestes Erscheinungsjahr zuerst
                return lhsMovie.year < rhsMovie.year
            }
        }

        return sorted.map { GridMovieItem(index: $0.offset, movie: $0.element) }
    }

    // MARK: - Grid-Ansicht (Cover-Only)

    @ViewBuilder
    private func posterGrid(items: [GridMovieItem], isBacklog: Bool) -> some View {
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
                    NavigationLink {
                        if isBacklog {
                            MovieDetailView(
                                movie: $movieStore.backlogMovies[item.index],
                                isBacklog: true
                            )
                        } else {
                            MovieDetailView(
                                movie: $movieStore.movies[item.index],
                                isBacklog: false
                            )
                        }
                    } label: {
                        ContentPosterGridCellView(movie: item.movie)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            if isBacklog {
                                movieStore.backlogMovies.remove(at: item.index)
                            } else {
                                movieStore.movies.remove(at: item.index)
                            }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
    }

    // MARK: - Watched-Liste

    @ViewBuilder
    private var watchedList: some View {
        let enumerated = Array(movieStore.movies.enumerated())
            .filter { _, movie in
                passesUserFilterForWatched(movie) && passesListSearch(movie, isBacklog: false)
            }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = displayScore(for: lhsMovie) ?? -Double.infinity
                let r = displayScore(for: rhsMovie) ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = displayScore(for: lhsMovie) ?? Double.infinity
                let r = displayScore(for: rhsMovie) ?? Double.infinity
                return l < r
            case .dateNewest:
                let l = lhsMovie.watchedDate ?? .distantPast
                let r = rhsMovie.watchedDate ?? .distantPast
                return l > r
            case .dateOldest:
                let l = lhsMovie.watchedDate ?? .distantFuture
                let r = rhsMovie.watchedDate ?? .distantFuture
                return l < r
            }
        }

        if !watchedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sorted.isEmpty {
            ContentUnavailableView(
                "Keine Treffer",
                systemImage: "magnifyingglass",
                description: Text("Passe den Suchbegriff an oder lösche ihn.")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(sorted, id: \.element.id) { pair in
                let index = pair.offset
                let movie = pair.element

                NavigationLink {
                    MovieDetailView(
                        movie: $movieStore.movies[index],
                        isBacklog: false
                    )
                } label: {
                    if selectedViewStyle == .compactList {
                        let displayRating = displayScore(for: movie)
                        ContentCompactMovieRowView(movie: movie, average: displayRating)
                    } else {
                        let displayRating = displayScore(for: movie)
                        ContentMovieRowView(movie: movie, average: displayRating)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(displaySettings.cardStyle == .cards ? .hidden : .automatic)
            }
            .onDelete { indexSet in
                let originalIndices = IndexSet(
                    indexSet.map { sorted[$0].offset }
                )
                movieStore.movies.remove(atOffsets: originalIndices)
            }
        }
    }

    // MARK: - Backlog-Liste

    @ViewBuilder
    private var backlogList: some View {
        let enumerated = Array(movieStore.backlogMovies.enumerated())
            .filter { _, movie in
                passesUserFilterForBacklog(movie) && passesListSearch(movie, isBacklog: true)
            }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = displayScore(for: lhsMovie) ?? -Double.infinity
                let r = displayScore(for: rhsMovie) ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = displayScore(for: lhsMovie) ?? Double.infinity
                let r = displayScore(for: rhsMovie) ?? Double.infinity
                return l < r
            case .dateNewest:
                // Im Backlog: neuestes Erscheinungsjahr zuerst
                return lhsMovie.year > rhsMovie.year
            case .dateOldest:
                // Im Backlog: ältestes Erscheinungsjahr zuerst
                return lhsMovie.year < rhsMovie.year
            }
        }

        if !backlogSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sorted.isEmpty {
            ContentUnavailableView(
                "Keine Treffer",
                systemImage: "magnifyingglass",
                description: Text("Passe den Suchbegriff an oder lösche ihn.")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
            ForEach(sorted, id: \.element.id) { pair in
                let index = pair.offset
                let movie = pair.element

                NavigationLink {
                    MovieDetailView(
                        movie: $movieStore.backlogMovies[index],
                        isBacklog: true
                    )
                } label: {
                    let displayRating = displayScore(for: movie)
                    if selectedViewStyle == .compactList {
                        ContentCompactMovieRowView(movie: movie, average: displayRating)
                    } else {
                        ContentMovieRowView(movie: movie, average: displayRating)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(displaySettings.cardStyle == .cards ? .hidden : .automatic)
            }
            .onDelete { indexSet in
                let originalIndices = IndexSet(
                    indexSet.map { sorted[$0].offset }
                )
                movieStore.backlogMovies.remove(atOffsets: originalIndices)
            }
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
