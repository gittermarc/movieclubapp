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

struct ContentView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore

    @State private var showingSearchMovie = false
    @State private var showingUsers = false
    @State private var showingStats = false
    @State private var showingTimeline = false       // 👈 NEU: Timeline
    @State private var showingGoals = false
    @State private var showingGroupSettings = false

    @State private var selectedMode: MovieListMode = .watched
    @State private var filterByUser: User? = nil
    @State private var selectedSort: MovieSortOption = .dateNewest

    /// Gibt an, ob es in der aktuellen Gruppe überhaupt schon Filme gibt
    private var hasAnyMoviesInCurrentGroup: Bool {
        !movieStore.movies.isEmpty || !movieStore.backlogMovies.isEmpty
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


                    // Gesehen / Backlog
                    Picker("Liste", selection: $selectedMode) {
                        ForEach(MovieListMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .top])

                    // Sortieren
                    HStack {
                        Text("Sortieren:")
                            .font(.subheadline)

                        Menu {
                            ForEach(MovieSortOption.allCases) { option in
                                Button(option.rawValue) {
                                    selectedSort = option
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedSort.rawValue)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                            }
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    // Filter nach Person
                    HStack {
                        Text("Filter:")
                            .font(.subheadline)

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
                            HStack {
                                if let user = filterByUser {
                                    Text(user.name)
                                } else {
                                    Text("Alle")
                                }
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)

                    // Hinweis, wie der Filter gerade funktioniert
                    if let _ = filterByUser {
                        if selectedMode == .watched {
                            Text("Filter zeigt nur Filme, in denen diese Person bewertet hat.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                        } else {
                            Text("Filter zeigt nur Filme, die von dieser Person vorgeschlagen wurden.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                        }
                    }

                    // MARK: - Inhalt: entweder Empty State oder Listen
                    if hasAnyMoviesInCurrentGroup {
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
                    } else {
                        // Empty State für ganz neue Gruppe / App
                        emptyStateView
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                        Spacer()
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
                        showingSearchMovie = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
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
                movieRow(movie: movie, average: movie.averageRating)
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
                movieRow(movie: movie, average: displayRating)
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

#Preview {
    ContentView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
}
