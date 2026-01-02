//
//  ContentView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI


enum MovieListMode: String, CaseIterable, Identifiable {
    case watched = "Gesehen"
    case backlog = "Backlog"

    var id: Self { self }
}

enum MovieSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "Zuletzt gesehen"
    case dateOldest = "Früheste zuerst"
    case ratingHigh = "Bewertung (hoch)"
    case ratingLow = "Bewertung (niedrig)"
    case titleAZ = "Titel A–Z"
    case titleZA = "Titel Z–A"

    var id: Self { self }
}


enum MovieViewStyle: String, CaseIterable, Identifiable {
    case posterGrid = "Cover-Grid"
    case cards = "Details"
    case compactList = "Liste (kompakt)"

    var id: Self { self }

    var icon: String {
        switch self {
        case .posterGrid: return "rectangle.grid.2x2"
        case .cards: return "rectangle.grid.1x2"
        case .compactList: return "list.bullet"
        }
    }
}

struct ContentView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore

    @State private var showingSearchMovie = false
    @State private var showingUsers = false
    @State private var showingStats = false
    @State private var showingTimeline = false       // 👈 NEU: Timeline
    @State private var showingGoals = false
    @State private var showingGroupSettings = false

    // MARK: - Onboarding / Quick Start
    @AppStorage("Onboarding_HasSeenQuickStart") private var hasSeenQuickStart: Bool = false
    @State private var showingQuickStart: Bool = false
    @State private var onboardingChecklistExpanded: Bool = true

    @State private var selectedMode: MovieListMode = .watched
    @State private var filterByUser: User? = nil
    @State private var selectedSort: MovieSortOption = .dateNewest

    // MARK: - View Style
    @AppStorage("ContentView_ViewStyle") private var viewStyleRaw: String = MovieViewStyle.cards.rawValue


    /// Gibt an, ob es in der aktuellen Gruppe überhaupt schon Filme gibt
    private var hasAnyMoviesInCurrentGroup: Bool {
        !movieStore.movies.isEmpty || !movieStore.backlogMovies.isEmpty
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


    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack {
                    // Aktuelle Gruppe anzeigen (falls vorhanden)
                    if let name = movieStore.currentGroupName {
                        let totalMoviesInGroup = movieStore.movies.count + movieStore.backlogMovies.count

                        VStack(spacing: 4) {
                            HStack {
                                Spacer()

                                Button {
                                    // Beim Tippen: Gruppenverwaltung öffnen
                                    showingGroupSettings = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.3.sequence.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.9))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Aktuelle Gruppe")
                                                .font(.caption2)
                                                .textCase(.uppercase)
                                                .foregroundStyle(.white.opacity(0.8))

                                            Text(name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.blue, Color.purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }

                            if totalMoviesInGroup > 0 {
                                Text("\(totalMoviesInGroup) Filme in dieser Gruppe")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
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
                    .padding(10)
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

                // iCloud-Sync Overlay (nur wenn aktiv)
                if movieStore.isSyncing {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                        Text("iCloud-Sync …")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
                }
            }
            .navigationTitle("The Movie Club")
            .onAppear {
                // Quick Start nur beim ersten Start – danach nicht mehr.
                if !hasSeenQuickStart {
                    showingQuickStart = true
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }

                    // 👇 NEU: Timeline-Button (zwischen Stats und Ziele)
                    Button {
                        showingTimeline = true
                    } label: {
                        Image(systemName: "rectangle.stack.fill")
                    }

                    Button {
                        showingGoals = true
                    } label: {
                        Image(systemName: "target")
                    }

                    Button {
                        showingUsers = true
                    } label: {
                        Image(systemName: "person.3")
                    }

                    Button {
                        trackSearchOpened()
                        showingSearchMovie = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .sheet(isPresented: $showingQuickStart, onDismiss: {
                // Wenn der User das Sheet wegwischt, nicht ewig wieder nerven.
                hasSeenQuickStart = true
            }) {
                QuickStartView(
                    onOpenGroups: {
                        showingQuickStart = false
                        showingGroupSettings = true
                    },
                    onOpenUsers: {
                        showingQuickStart = false
                        showingUsers = true
                    },
                    onOpenSearch: {
                        showingQuickStart = false
                        trackSearchOpened()
                        showingSearchMovie = true
                    },
                    onDone: {
                        hasSeenQuickStart = true
                        showingQuickStart = false
                    }
                )
            }

            .sheet(isPresented: $showingSearchMovie) {
                MovieSearchView(
                    existingWatched: movieStore.movies,
                    existingBacklog: movieStore.backlogMovies,
                    onAddToWatched: { newMovie in
                        // Film mit Gruppen-Infos „anreichern“
                        var movieWithGroup = newMovie
                        movieWithGroup.groupId = movieStore.currentGroupId
                        movieWithGroup.groupName = movieStore.currentGroupName

                        // Eindeutigkeit weiterhin über Titel + Jahr
                        let isSame: (Movie) -> Bool = { movie in
                            movie.title == movieWithGroup.title && movie.year == movieWithGroup.year
                        }

                        // Wenn noch nicht in „Gesehen“, hinzufügen
                        if !movieStore.movies.contains(where: isSame) {
                            movieStore.movies.append(movieWithGroup)
                        }

                        // Falls im Backlog vorhanden, dort entfernen
                        movieStore.backlogMovies.removeAll(where: isSame)
                    },
                    onAddToBacklog: { newMovie in
                        var movieWithGroup = newMovie
                        movieWithGroup.groupId = movieStore.currentGroupId
                        movieWithGroup.groupName = movieStore.currentGroupName

                        let isSame: (Movie) -> Bool = { movie in
                            movie.title == movieWithGroup.title && movie.year == movieWithGroup.year
                        }

                        // Wenn der Film schon als gesehen markiert ist → nicht in den Backlog aufnehmen
                        guard !movieStore.movies.contains(where: isSame) else {
                            return
                        }

                        // Nur hinzufügen, wenn noch nicht im Backlog
                        if !movieStore.backlogMovies.contains(where: isSame) {
                            movieStore.backlogMovies.append(movieWithGroup)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingUsers) {
                UsersView()
            }
            .sheet(isPresented: $showingStats) {
                StatsView()
            }
            // 👇 NEU: Timeline-Sheet
            .sheet(isPresented: $showingTimeline) {
                TimelineView()
                    .environmentObject(movieStore)
                    .environmentObject(userStore)
            }
            .sheet(isPresented: $showingGoals) {
                GoalsView()
                    .environmentObject(movieStore)
                    .environmentObject(userStore)
            }
            .sheet(isPresented: $showingGroupSettings) {
                GroupSettingsView()
            }
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
                        .foregroundStyle(.blue)

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
                        subtitle: "Erstellen oder beitreten (Invite-Code)",
                        actionTitle: "Gruppen"
                    ) {
                        showingGroupSettings = true
                    }

                    onboardingRow(
                        isDone: isMembersStepComplete,
                        title: "Mitglieder hinzufügen",
                        subtitle: "Damit Bewertungen & Vorschläge Sinn ergeben",
                        actionTitle: "Mitglieder"
                    ) {
                        showingUsers = true
                    }

                    onboardingRow(
                        isDone: isFirstMovieStepComplete,
                        title: "Ersten Film hinzufügen",
                        subtitle: "Suche bei TMDb und pack ihn in „Gesehen“ oder Backlog",
                        actionTitle: "Suche"
                    ) {
                        trackSearchOpened()
                        showingSearchMovie = true
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
        HStack(spacing: 8) {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
                showingSearchMovie = true
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
                    showingUsers = true
                } label: {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Mitglieder hinzufügen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showingGroupSettings = true
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
        return movie.ratings.contains {
            $0.reviewerName.lowercased() == user.name.lowercased()
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



    // MARK: - Grid-Daten (gefiltert + sortiert)

    private struct GridMovieItem: Identifiable {
        let index: Int
        let movie: Movie
        var id: String { String(describing: movie.id) }
    }

    private var watchedGridItems: [GridMovieItem] {
        let enumerated = Array(movieStore.movies.enumerated())
            .filter { _, movie in passesUserFilterForWatched(movie) }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? -Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? Double.infinity
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
            .filter { _, movie in passesUserFilterForBacklog(movie) }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? -Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? Double.infinity
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
        if items.isEmpty {
            ContentUnavailableView(
                "Keine Filme",
                systemImage: "film",
                description: Text("In dieser Ansicht gibt's gerade nichts anzuzeigen.")
            )
            .padding(.top, 32)
            .padding(.horizontal)
        } else {
            let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

            LazyVGrid(columns: columns, spacing: 12) {
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
                AsyncImage(url: url) { phase in
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
        .frame(height: 170)
        .clipped()
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Kompakte Listenzeile

    @ViewBuilder
    private func compactMovieRow(movie: Movie, average: Double?) -> some View {
        HStack(spacing: 12) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
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

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer()

            if let avg = average {
                Text(String(format: "%.1f", avg))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("-")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Watched-Liste

    @ViewBuilder
    private var watchedList: some View {
        let enumerated = Array(movieStore.movies.enumerated())
            .filter { _, movie in passesUserFilterForWatched(movie) }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? -Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? Double.infinity
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
                    let displayRating = movie.averageRating ?? movie.tmdbRating
                    compactMovieRow(movie: movie, average: displayRating)
                } else {
                    movieRow(movie: movie, average: movie.averageRating)
                }
            }
        }
        .onDelete { indexSet in
            let originalIndices = IndexSet(
                indexSet.map { sorted[$0].offset }
            )
            movieStore.movies.remove(atOffsets: originalIndices)
        }
    }

    // MARK: - Backlog-Liste

    @ViewBuilder
    private var backlogList: some View {
        let enumerated = Array(movieStore.backlogMovies.enumerated())
            .filter { _, movie in passesUserFilterForBacklog(movie) }

        let sorted = enumerated.sorted { lhs, rhs in
            let lhsMovie = lhs.element
            let rhsMovie = rhs.element

            switch selectedSort {
            case .titleAZ:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedAscending
            case .titleZA:
                return lhsMovie.title.localizedCaseInsensitiveCompare(rhsMovie.title) == .orderedDescending
            case .ratingHigh:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? -Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? -Double.infinity
                return l > r
            case .ratingLow:
                let l = lhsMovie.averageRating ?? lhsMovie.tmdbRating ?? Double.infinity
                let r = rhsMovie.averageRating ?? rhsMovie.tmdbRating ?? Double.infinity
                return l < r
            case .dateNewest:
                // Im Backlog: neuestes Erscheinungsjahr zuerst
                return lhsMovie.year > rhsMovie.year
            case .dateOldest:
                // Im Backlog: ältestes Erscheinungsjahr zuerst
                return lhsMovie.year < rhsMovie.year
            }
        }

        ForEach(sorted, id: \.element.id) { pair in
            let index = pair.offset
            let movie = pair.element

            NavigationLink {
                MovieDetailView(
                    movie: $movieStore.backlogMovies[index],
                    isBacklog: true
                )
            } label: {
                let displayRating = movie.averageRating ?? movie.tmdbRating
                if selectedViewStyle == .compactList {
                    compactMovieRow(movie: movie, average: displayRating)
                } else {
                    movieRow(movie: movie, average: displayRating)
                }
            }
        }
        .onDelete { indexSet in
            let originalIndices = IndexSet(
                indexSet.map { sorted[$0].offset }
            )
            movieStore.backlogMovies.remove(atOffsets: originalIndices)
        }
    }

    // MARK: - Zeilen-Layout

    @ViewBuilder
    private func movieRow(movie: Movie, average: Double?) -> some View {
        HStack(spacing: 12) {
            // Poster
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
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

                    if let dateText = movie.watchedDateText {
                        Text("• \(dateText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let location = movie.watchedLocation, !location.isEmpty {
                        Text("• \(location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let sugg = movie.suggestedBy, !sugg.isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let avg = average {
                Text(String(format: "%.1f", avg))
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("-")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.vertical, 4)
    }
}

private struct QuickStartView: View {
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
                .foregroundStyle(.blue)

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
}
