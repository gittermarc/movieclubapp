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

    // MARK: - Sync mini status (subtle)

    private var shouldShowSyncStatusLine: Bool {
        if !networkMonitor.isConnected { return true }
        if movieStore.isSyncing || userStore.isSyncing { return true }
        if movieStore.pendingCloudChangesCount > 0 { return true }
        if let err = movieStore.lastCloudSyncError, !err.isEmpty { return true }
        return false
    }

    private var syncStatusLineIcon: String {
        if !networkMonitor.isConnected { return "wifi.slash" }
        if movieStore.isSyncing || userStore.isSyncing { return "arrow.triangle.2.circlepath" }
        if let err = movieStore.lastCloudSyncError, !err.isEmpty { return "exclamationmark.triangle" }
        if movieStore.pendingCloudChangesCount > 0 { return "clock.arrow.circlepath" }
        return "checkmark.circle"
    }

    private var syncStatusLineText: String {
        if !networkMonitor.isConnected {
            return "Offline – Änderungen werden später synchronisiert"
        }
        if movieStore.isSyncing || userStore.isSyncing {
            return "Synchronisiere …"
        }
        if movieStore.pendingCloudChangesCount > 0 {
            let c = movieStore.pendingCloudChangesCount
            return c == 1 ? "1 Änderung ausstehend" : "\(c) Änderungen ausstehend"
        }
        if let err = movieStore.lastCloudSyncError, !err.isEmpty {
            return "Sync-Problem – Details in Einstellungen"
        }
        return ""
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
                    // Aktuelle Gruppe anzeigen (falls vorhanden)
                    if let name = movieStore.currentGroupName {
                        let totalMoviesInGroup = movieStore.movies.count + movieStore.backlogMovies.count

                        ContentContextBar(
                            groupName: name,
                            totalMoviesInGroup: totalMoviesInGroup,
                            tintColor: displaySettings.tintColor,
                            activeMemberDisplayName: activeMemberDisplayName,
                            activeMemberInitials: activeMemberInitials,
                            hasActiveMemberSelected: hasActiveMemberSelected,
                            onTapGroup: { route = .groupSettings },
                            onTapActiveMember: { route = .users }
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                    }


                    // ✅ Onboarding: Quick Start / Setup-Checkliste
                    if shouldShowOnboardingChecklist {
                        onboardingChecklistCard
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    // Gesehen / Backlog
                    Picker("Liste", selection: $selectedMode) {
                        ForEach(MovieListMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .top])

                    // Wenn wir umschalten, Keyboard nicht "festkleben" lassen.
                    .onChange(of: selectedMode) { _, _ in
                        listSearchIsFocused = false
                    }

                    // ✅ Kompakte, gebündelte Sortier-/Filter-Leiste
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            // Sortieren
                            Menu {
                                ForEach(MovieSortOption.allCases) { option in
                                    Button(option.rawValue) {
                                        selectedSort = option
                                    }
                                }
                            } label: {
                                controlChip(
                                    icon: "arrow.up.arrow.down",
                                    title: selectedSort.rawValue
                                )
                            }

                            // Filter
                            Menu {
                                Button("Alle") {
                                    filterByUser = nil
                                }

                                if userStore.users.isEmpty {
                                    Text("Keine Mitglieder")
                                } else {
                                    ForEach(userStore.users) { user in
                                        Button(user.name) {
                                            filterByUser = user
                                        }
                                    }
                                }
                            } label: {
                                controlChip(
                                    icon: "line.3.horizontal.decrease.circle",
                                    title: filterLabelText
                                )
                            }

                            // Ansicht
                            Menu {
                                ForEach(MovieViewStyle.allCases) { style in
                                    Button {
                                        viewStyleRaw = style.rawValue
                                    } label: {
                                        Label(style.rawValue, systemImage: style.icon)
                                    }
                                }
                            } label: {
                                controlChip(
                                    icon: selectedViewStyle.icon,
                                    title: selectedViewStyle.rawValue
                                )
                            }

                            // Reset-Button nur wenn Filter aktiv
                            if filterByUser != nil {
                                Button {
                                    filterByUser = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Filter zurücksetzen")
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer(minLength: 0)
                        }

                        if let hint = filterHintText {
                            Divider()
                                .opacity(0.7)

                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(m.cardPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                    if shouldShowSyncStatusLine {
                        HStack(spacing: 6) {
                            Image(systemName: syncStatusLineIcon)
                            Text(syncStatusLineText)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                        .accessibilityLabel(syncStatusLineText)
                    }

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

    // MARK: - Pull to Refresh

    /// Pull-to-refresh entry point:
    /// - refresh Movies (CloudKit)
    /// - refresh Members (CloudKit)
    private func performPullToRefresh() async {
        // Parallelisieren, damit's flotter ist (und du nicht gefühlt 'nen Kaffee kochen kannst).
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await movieStore.refreshFromCloud(force: true)
            }
            group.addTask {
                await userStore.refreshFromCloud(force: true)
            }
            await group.waitForAll()
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

    private var onboardingChecklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    onboardingChecklistExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Start")
                            .font(.subheadline.weight(.semibold))
                        Text("\(onboardingStepsCompletedCount) von 4 erledigt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: onboardingChecklistExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if onboardingChecklistExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    onboardingRow(
                        isDone: isGroupStepComplete,
                        title: "Gruppe einrichten",
                        subtitle: "Erstellen oder per iCloud-Einladung beitreten",
                        actionTitle: "Gruppen"
                    ) {
	                        route = .groupSettings
                    }

                    onboardingRow(
                        isDone: isMembersStepComplete,
                        title: "Mitglieder hinzufügen",
                        subtitle: "Damit Bewertungen & Vorschläge Sinn ergeben",
                        actionTitle: "Mitglieder"
                    ) {
	                        route = .users
                    }

                    onboardingRow(
                        isDone: isFirstMovieStepComplete,
                        title: "Ersten Film hinzufügen",
                        subtitle: "Suche bei TMDb und pack ihn in „Gesehen“ oder Backlog",
                        actionTitle: "Suche"
                    ) {
                        trackSearchOpened()
	                        route = .movieSearch
                    }

                    onboardingRow(
                        isDone: isFirstRatingStepComplete,
                        title: "Erste Bewertung abgeben",
                        subtitle: hasAnyMoviesInCurrentGroup
                            ? "Tippe auf einen Film in der Liste und bewerte ihn"
                            : "Sobald ein Film drin ist, kannst du ihn bewerten",
                        actionTitle: nil,
                        action: nil
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    @ViewBuilder
    private func onboardingRow(
        isDone: Bool,
        title: String,
        subtitle: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isDone ? Color.green : Color.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let actionTitle, let action, !isDone {
                Button(actionTitle) {
                    action()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Compact Controls UI

    @ViewBuilder
    private func controlChip(icon: String, title: String) -> some View {
        HStack(spacing: m.chipContentSpacing) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline)
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, m.chipHorizontalPadding)
        .padding(.vertical, m.chipVerticalPadding)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                        posterGridCell(movie: item.movie)
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

    @ViewBuilder
    private func posterGridCell(movie: Movie) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: g.cellHeight)
        .clipped()
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Kompakte Listenzeile

    @ViewBuilder
    private func compactMovieRow(movie: Movie, average: Double?) -> some View {
        let row = HStack(spacing: m.compactRowHStackSpacing) {
            if displaySettings.showPosterInCompactList {
                if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 34, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.12))
                    .frame(width: 34, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            if displaySettings.showRatings {
                if let avg = average {
                Text(String(format: "%.1f", avg))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("-")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            }
        }

        if displaySettings.cardStyle == .cards {
            row
                .padding(.vertical, m.compactRowVerticalPadding)
                .padding(.horizontal, m.rowPadding)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                .padding(.vertical, m.cardVerticalSpacing)
        } else {
            row
                .padding(.vertical, m.compactRowVerticalPadding)
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
                        compactMovieRow(movie: movie, average: displayRating)
                    } else {
                        let displayRating = displayScore(for: movie)
                        movieRow(movie: movie, average: displayRating)
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
                        compactMovieRow(movie: movie, average: displayRating)
                    } else {
                        movieRow(movie: movie, average: displayRating)
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

    // MARK: - Zeilen-Layout

    @ViewBuilder
    private func movieRow(movie: Movie, average: Double?) -> some View {
        let row = HStack(spacing: m.rowHStackSpacing) {
            // Poster
            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "film")
                            }
                    @unknown default:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 50, height: 75)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if displaySettings.showWatchedDate, let dateText = movie.watchedDateText {
                        Text("• \(dateText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if displaySettings.showWatchedLocation, let location = movie.watchedLocation, !location.isEmpty {
                        Text("• \(location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if displaySettings.showSuggestedBy, let sugg = movie.suggestedBy, !sugg.isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if displaySettings.showRatings {
                if let avg = average {
                Text(String(format: "%.1f", avg))
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("-")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            }
        }

        if displaySettings.cardStyle == .cards {
            row
                .padding(m.rowPadding)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.vertical, m.cardVerticalSpacing)
        } else {
            row
                .padding(.vertical, 8)
        }
    }
}

struct QuickStartView: View {
    var onOpenGroups: () -> Void
    var onOpenUsers: () -> Void
    var onOpenSearch: () -> Void
    var onDone: () -> Void

    @State private var page: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                TabView(selection: $page) {
                    QuickStartPage(
                        icon: "person.3.sequence.fill",
                        title: "Erstmal eine Gruppe",
                        text: "Erstelle eine Gruppe oder tritt einer bestehenden bei. So bleiben Filme & Bewertungen sauber getrennt."
                    )
                    .tag(0)

                    QuickStartPage(
                        icon: "person.3.fill",
                        title: "Mitglieder hinzufügen",
                        text: "Füg die Leute hinzu, die bewerten sollen. Sonst heißt am Ende jeder „Unbekannt“ – und das ist nur bei Thrillern cool."
                    )
                    .tag(1)

                    QuickStartPage(
                        icon: "magnifyingglass",
                        title: "Ersten Film reinwerfen",
                        text: "Suche auf TMDb und füge Filme zu „Gesehen“ oder in den Backlog hinzu. Ab dann läuft’s von allein."
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: 420)

                // Action Buttons (kontextabhängig)
                VStack(spacing: 10) {
                    if page == 0 {
                        Button {
                            onOpenGroups()
                        } label: {
                            Label("Gruppen verwalten", systemImage: "person.3.sequence.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else if page == 1 {
                        Button {
                            onOpenUsers()
                        } label: {
                            Label("Mitglieder hinzufügen", systemImage: "person.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            onOpenSearch()
                        } label: {
                            Label("Film suchen", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack(spacing: 12) {
                        Button("Überspringen") {
                            onDone()
                        }
                        .buttonStyle(.bordered)

                        Button(page == 2 ? "Fertig" : "Weiter") {
                            if page < 2 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    page += 1
                                }
                            } else {
                                onDone()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .navigationTitle("Willkommen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { onDone() }
                }
            }
        }
    }
}

private struct QuickStartPage: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
    }
}

#Preview {
    ContentView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
        .environmentObject(NetworkMonitor.shared)
        .environmentObject(DisplaySettings())
}
