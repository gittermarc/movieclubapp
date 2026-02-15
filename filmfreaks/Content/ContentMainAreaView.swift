//
//  ContentMainAreaView.swift
//  filmfreaks
//
//  Extracted from ContentView.swift to keep the main file smaller and easier to maintain.
//

internal import SwiftUI

struct ContentMainAreaView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    let hasAnyMoviesInCurrentGroup: Bool

    @Binding var selectedMode: MovieListMode
    let selectedViewStyle: MovieViewStyle

    let watchedListItems: [IndexedMovie]
    let backlogListItems: [IndexedMovie]
    let watchedGridItems: [IndexedMovie]
    let backlogGridItems: [IndexedMovie]

    @Binding var watchedSearchText: String
    @Binding var backlogSearchText: String

    let shouldShowListSearchBar: Bool
    let listSearchPlaceholder: String
    let activeListSearchText: Binding<String>
    @FocusState.Binding var listSearchIsFocused: Bool

    let metrics: DisplaySettings.LayoutMetrics
    let displayScore: (Movie) -> Double?

    let onRefresh: () async -> Void
    let onOpenSearch: () -> Void
    let onOpenUsers: () -> Void
    let onOpenGroupSettings: () -> Void

    private var g: DisplaySettings.PosterGridMetrics { displaySettings.posterGridMetrics }

    @State private var pendingGridDelete: MovieDeleteConfirmation?

    private var isPresentingGridDeleteAlert: Binding<Bool> {
        Binding(
            get: { pendingGridDelete != nil },
            set: { newValue in
                if !newValue { pendingGridDelete = nil }
            }
        )
    }

    var body: some View {
        Group {
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
                        bottomSearchBar
                    }
                    .refreshable {
                        await onRefresh()
                    }

                case .cards, .compactList:
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
                        bottomSearchBar
                    }
                    .refreshable {
                        await onRefresh()
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
                    await onRefresh()
                }
            }
        }
        .alert(
            pendingGridDelete?.alertTitle ?? "Film löschen?",
            isPresented: isPresentingGridDeleteAlert,
            presenting: pendingGridDelete
        ) { pending in
            Button("Löschen", role: .destructive) {
                confirmGridDelete(pending)
            }
            Button("Abbrechen", role: .cancel) {
                pendingGridDelete = nil
            }
        } message: { pending in
            Text(pending.alertMessage)
        }
    }

    @ViewBuilder
    private var bottomSearchBar: some View {
        if shouldShowListSearchBar {
            InListSearchBar(
                placeholder: listSearchPlaceholder,
                text: activeListSearchText,
                isFocused: $listSearchIsFocused,
                metrics: metrics
            )
        }
    }

    // MARK: - Empty State

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
                onOpenSearch()
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
                    onOpenUsers()
                } label: {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Mitglieder hinzufügen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onOpenGroupSettings()
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

    // MARK: - Grid (Cover-Only)

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
                                    requestGridDelete(movie: movie, isBacklog: true)
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
                                    requestGridDelete(movie: movie, isBacklog: false)
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

    // MARK: - Deletion confirmation (Grid)

    private func requestGridDelete(movie: Movie, isBacklog: Bool) {
        pendingGridDelete = MovieDeleteConfirmation(
            movieIds: [movie.id],
            movieTitles: [movie.title],
            isBacklog: isBacklog
        )
    }

    private func confirmGridDelete(_ pending: MovieDeleteConfirmation) {
        let ids = Set(pending.movieIds)
        if pending.isBacklog {
            movieStore.backlogMovies.removeAll { ids.contains($0.id) }
        } else {
            movieStore.movies.removeAll { ids.contains($0.id) }
        }
        pendingGridDelete = nil
    }
}
