//
//  MovieSearchView.swift
//  filmfreaks
//

internal import SwiftUI


// MARK: - MovieSearchView

struct MovieSearchView: View {


    @Environment(\.dismiss) private var dismiss

    // Keyboard (gegen Content-Jump beim Fokus)
    @StateObject var keyboard = KeyboardMonitor()

    // Suche
    @State var query: String = ""
    @State var isLoading: Bool = false
    @State var errorMessage: String?
    @State var results: [TMDbMovieResult] = []

    // Pagination
    @State var currentPage: Int = 1
    @State var totalPages: Int = 1
    @State var totalResults: Int = 0
    @State var isLoadingMore: Bool = false

    // Sortierung
    @State var selectedSort: MovieSearchSortOption = .relevance

    // Detail-Sheet
    @State private var detailResult: TMDbMovieResult?

    // Toast
    @State var toastMessage: String?
    @State var showToast: Bool = false

    // Markierung: schon in Listen
    @State var localWatchedKeys: Set<String>
    @State var localBacklogKeys: Set<String>

    // NEU: Such-Historie
    @State var recentQueries: [String] = SearchHistoryManager.load()

    // Skeleton-Pulsing
    @State private var skeletonPulse: Bool = false

    // Medium scannen (Live Text)
    @State var showScanner: Bool = false
    @State var scannerError: String?
    @State var showScannerError: Bool = false

    // NEU: Kandidatenhilfe nach Scan
    @State var scannerCandidates: [String] = []
    @State var candidatePickerItems: [String] = []
    @State var showCandidatePicker: Bool = false
    @State var lastTappedScanText: String?

    // Optional: Focus fürs Suchfeld (bei „Manuell bearbeiten“)
    @FocusState var isSearchFieldFocused: Bool

    // ✅ NEU: Empfehlungen (Inspiration)
    @State var recommendations: [TMDbMovieResult] = []
    @State var isLoadingRecommendations: Bool = false
    @State var recommendationsError: String?
    @State var recommendationsSeedTitle: String?
    @State var recommendationsLastUpdated: Date?

    let recommendationsCacheMaxAge: TimeInterval = 60 * 60 * 24 // 24h
    let recommendationsFallbackToPopularIfNoSeeds: Bool = true

    let existingWatched: [Movie]
    let existingBacklog: [Movie]

    var onAddToWatched: (Movie) -> Void
    var onAddToBacklog: (Movie) -> Void

    // Custom init, um die Sets aus den bestehenden Filmen zu initialisieren
    init(
        existingWatched: [Movie],
        existingBacklog: [Movie],
        onAddToWatched: @escaping (Movie) -> Void,
        onAddToBacklog: @escaping (Movie) -> Void
    ) {
        self.existingWatched = existingWatched
        self.existingBacklog = existingBacklog
        self.onAddToWatched = onAddToWatched
        self.onAddToBacklog = onAddToBacklog

        _localWatchedKeys = State(
            initialValue: Set(existingWatched.map { MovieSearchMapper.key(for: $0) })
        )
        _localBacklogKeys = State(
            initialValue: Set(existingBacklog.map { MovieSearchMapper.key(for: $0) })
        )
        // recentQueries kommt über den Default-Initializer (s.o.)
    }
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {

                    // ✅ Zuletzt gesucht
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !recentQueries.isEmpty {
                        MovieSearchRecentQueriesView(
                            recentQueries: recentQueries,
                            onTap: { term in
                                query = term
                                Task { await performSearch(reset: true) }
                            },
                            onClearHistory: {
                                SearchHistoryManager.clear()
                                recentQueries = []
                            }
                        )
                    }

                    // ✅ Inspirationen nur im „Idle“-State
                    if shouldShowRecommendations {
                        MovieSearchRecommendationsSectionView(
                            recommendations: recommendations,
                            isLoading: isLoadingRecommendations,
                            errorMessage: recommendationsError,
                            seedTitle: recommendationsSeedTitle,
                            lastUpdated: recommendationsLastUpdated,
                            skeletonPulse: $skeletonPulse,
                            onRefresh: {
                                Task { await loadRecommendationsIfNeeded(force: true) }
                            },
                            cardContent: { result in
                                let key = MovieSearchMapper.key(for: result)
                                let isWatched = localWatchedKeys.contains(key)
                                let isBacklog = localBacklogKeys.contains(key)

                                MovieSearchRecommendationCardView(
                                    result: result,
                                    isInWatched: isWatched,
                                    isInBacklog: isBacklog,
                                    onOpenDetail: {
                                        openDetail(result)
                                    },
                                    onAddToWatched: {
                                        let movie = MovieSearchMapper.convertToMovie(result)
                                        onAddToWatched(movie)
                                        localWatchedKeys.insert(key)
                                        showConfirmation("Zu „Gesehen“ hinzugefügt")
                                    },
                                    onAddToBacklog: {
                                        let movie = MovieSearchMapper.convertToMovie(result)
                                        onAddToBacklog(movie)
                                        localBacklogKeys.insert(key)
                                        showConfirmation("Zum Backlog hinzugefügt")
                                    }
                                )
                            }
                        )
                    }

                    // Fehleranzeige
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    // Ergebnisse / Skeleton
                    if isLoading && results.isEmpty {
                        MovieSearchSkeletonResultsView(
                            pulse: $skeletonPulse,
                            keyboardHeight: keyboard.height,
                            keyboardAnimationDuration: keyboard.animationDuration
                        )
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                skeletonPulse.toggle()
                            }
                        }
                    } else if results.isEmpty && !isLoading && !query.isEmpty {
                        Text("Keine Treffer. Bitte prüfe die Schreibweise.")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else if !sortedResults.isEmpty {
                        MovieSearchResultsListView(
                            results: sortedResults,
                            canLoadMore: canLoadMore,
                            isLoadingMore: isLoadingMore,
                            totalResults: totalResults,
                            keyboardHeight: keyboard.height,
                            keyboardAnimationDuration: keyboard.animationDuration,
                            onLoadMore: {
                                Task { await loadMore() }
                            },
                            rowContent: { result in
                                let key = MovieSearchMapper.key(for: result)
                                let isWatched = localWatchedKeys.contains(key)
                                let isBacklog = localBacklogKeys.contains(key)

                                MovieSearchResultCardView(
                                    result: result,
                                    isInWatched: isWatched,
                                    isInBacklog: isBacklog,
                                    onOpenDetail: {
                                        openDetail(result)
                                    },
                                    onAddToWatched: {
                                        let movie = MovieSearchMapper.convertToMovie(result)
                                        onAddToWatched(movie)
                                        localWatchedKeys.insert(key)
                                        showConfirmation("Zu „Gesehen“ hinzugefügt")
                                    },
                                    onAddToBacklog: {
                                        let movie = MovieSearchMapper.convertToMovie(result)
                                        onAddToBacklog(movie)
                                        localBacklogKeys.insert(key)
                                        showConfirmation("Zum Backlog hinzugefügt")
                                    }
                                )
                            }
                        )
                    } else if !isLoading && query.isEmpty && recentQueries.isEmpty && !isSearchFieldFocused {
                        // Nur anzeigen, wenn wirklich gar kein Verlauf existiert
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Suche nach Filmtiteln auf TMDb")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
            .navigationTitle("Film suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            // Sticky Header
            .safeAreaInset(edge: .top, spacing: 0) {
                stickySearchHeader
            }
            .sheet(item: $detailResult) { result in
                let key = MovieSearchMapper.key(for: result)
                let isWatched = localWatchedKeys.contains(key)
                let isBacklog = localBacklogKeys.contains(key)

                SearchResultDetailView(
                    result: result,
                    isInitiallyInWatched: isWatched,
                    isInitiallyInBacklog: isBacklog,
                    onAddToWatched: { movie in
                        onAddToWatched(movie)
                        localWatchedKeys.insert(key)
                    },
                    onAddToBacklog: { movie in
                        onAddToBacklog(movie)
                        localBacklogKeys.insert(key)
                    }
                )
            }

            // Scanner-Sheet
            .sheet(isPresented: $showScanner) {
                if #available(iOS 16.0, *) {
                    MediaTitleScannerView(
                        onPickText: { scanned in
                            // Scanner schließen und dann Kandidaten anzeigen
                            lastTappedScanText = scanned
                            showScanner = false

                            let ranked = MovieTitleCandidateRanker.rank(recognized: scannerCandidates, tapped: scanned)

                            // Wenn wir nur 1 wirklich guten Kandidaten haben: direkt suchen (nice UX)
                            if let only = ranked.first, ranked.count == 1 {
                                query = only
                                Task { await performSearch(reset: true) }
                            } else {
                                candidatePickerItems = ranked
                                showCandidatePicker = true
                            }
                        },
                        onCancel: {
                            showScanner = false
                        },
                        onRecognizedTextsChanged: { texts in
                            // laufend aktualisieren
                            scannerCandidates = texts
                        }
                    )
                } else {
                    Text("„Medium scannen“ benötigt iOS 16 oder neuer.")
                        .padding()
                }
            }

            // Kandidaten-Picker nach Scan
            .sheet(isPresented: $showCandidatePicker) {
                MovieSearchCandidatePickerSheetView(
                    tappedText: lastTappedScanText,
                    candidates: candidatePickerItems,
                    onSelectCandidate: { candidate in
                        showCandidatePicker = false
                        query = candidate
                        Task { await performSearch(reset: true) }
                    },
                    onManualEdit: { rawFallback in
                        query = MovieTitleCandidateRanker.cleanup(rawFallback)
                        showCandidatePicker = false

                        // Fokus ins Suchfeld
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isSearchFieldFocused = true
                        }
                    },
                    onCancel: {
                        showCandidatePicker = false
                    }
                )
            }

            // Scanner-Fehler
            .alert("Medium scannen", isPresented: $showScannerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerError ?? "Unbekannter Fehler.")
            }

            // Toast-Overlay unten
            .overlay(alignment: .bottom) {
                if showToast, let toastMessage {
                    MovieSearchToastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            // ✅ Empfehlungen laden, sobald die View da ist (nur wenn Suchfeld leer)
            await loadRecommendationsIfNeeded()
        }
        .onChange(of: query) { _, newValue in
            // ✅ Sobald das Suchfeld wieder leer wird, können Empfehlungen erscheinen
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                Task { await loadRecommendationsIfNeeded() }
            }
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            // Wenn der Fokus weg ist und die Suche leer ist, dürfen Inspirationen wieder auftauchen.
            if !focused {
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    Task { await loadRecommendationsIfNeeded() }
                }
            }
        }
    }

    // MARK: - Sticky Suchkopf

    private var stickySearchHeader: some View {
        MovieSearchStickyHeaderView(
            query: $query,
            selectedSort: $selectedSort,
            headerTopSpacer: headerTopSpacer,
            isLoading: isLoading,
            resultsCount: results.count,
            totalResults: totalResults,
            keyboardAnimationDuration: keyboard.animationDuration,
            isSearchFieldFocused: isSearchFieldFocused,
            focusBinding: $isSearchFieldFocused,
            onSubmit: {
                Task { await performSearch(reset: true) }
            },
            onClear: {
                clearSearch()
            },
            onScanTap: {
                handleScanTap()
            }
        )
    }

    // MARK: - Routing

    private func openDetail(_ result: TMDbMovieResult) {
        detailResult = result
    }

}

#Preview {
    MovieSearchView(
        existingWatched: [],
        existingBacklog: [],
        onAddToWatched: { _ in },
        onAddToBacklog: { _ in }
    )
    .environmentObject(DisplaySettings())
}