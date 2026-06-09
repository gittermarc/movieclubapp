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
    @StateObject var viewModel: MovieSearchViewModel

    @AppStorage(WatchProvidersRegionSettings.storageKey)
    var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    // Sortierung
    @State var selectedSort: MovieSearchSortOption = .relevance
    @State var resultsModel = MovieSearchResultsModel()

    // Detail-Sheet
    @State private var detailResult: TMDbMovieResult?

    // Toast
    @State var toastMessage: String?
    @State var showToast: Bool = false

    // Markierung: schon in Listen
    @State var localWatchedKeys: Set<String>
    @State var localBacklogKeys: Set<String>

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
        _viewModel = StateObject(
            wrappedValue: MovieSearchViewModel(existingWatched: existingWatched, existingBacklog: existingBacklog)
        )
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

                VStack(spacing: 0) {
                    stickySearchHeader

                    Group {
                        if viewState.showsIdleSurface {
                            MovieSearchIdleContentView(
                                viewState: viewState,
                                recentQueries: viewModel.recentQueries,
                                discoveryShelves: viewModel.discoveryShelves,
                                isLoadingDiscovery: viewModel.isLoadingDiscovery,
                                discoveryError: viewModel.discoveryError,
                                skeletonPulse: $skeletonPulse,
                                membershipState: membershipState(for:),
                                onRecentQueryTap: handleRecentQueryTap,
                                onClearHistory: handleClearHistory,
                                onRefreshDiscovery: handleDiscoveryRefresh,
                                onOpenDetail: openDetail,
                                onAddToWatched: handleAddToWatched,
                                onAddToBacklog: handleAddToBacklog
                            )
                        } else {
                            MovieSearchResultsContentView(
                                viewState: viewState,
                                errorMessage: errorMessage,
                                results: resultsModel.sortedResults,
                                canLoadMore: canLoadMore,
                                isLoadingMore: viewModel.isLoadingMore,
                                totalResults: viewModel.totalResults,
                                keyboardHeight: keyboard.height,
                                keyboardAnimationDuration: keyboard.animationDuration,
                                skeletonPulse: $skeletonPulse,
                                membershipState: membershipState(for:),
                                onLoadMore: startLoadMore,
                                onOpenDetail: openDetail,
                                onAddToWatched: handleAddToWatched,
                                onAddToBacklog: handleAddToBacklog
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Film suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        cancelSearchTasks()
                        dismiss()
                    }
                }
            }
            .sheet(item: $detailResult) { result in
                let key = MovieSearchMapper.key(for: result)
                let isWatched = localWatchedKeys.contains(key)
                let isBacklog = localBacklogKeys.contains(key)

                SearchResultDetailView(
                    result: result,
                    existingWatched: existingWatched,
                    existingBacklog: existingBacklog,
                    isInitiallyInWatched: isWatched,
                    isInitiallyInBacklog: isBacklog,
                    onAddToWatched: { movie in
                        handleDetailAddToWatched(movie, key: MovieSearchMapper.key(for: movie))
                    },
                    onAddToBacklog: { movie in
                        handleDetailAddToBacklog(movie, key: MovieSearchMapper.key(for: movie))
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
                                startSearch(reset: true)
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
                        startSearch(reset: true)
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
            await loadDiscoveryIfNeeded()
        }
        .onChange(of: query) { _, newValue in
            // ✅ Sobald das Suchfeld wieder leer wird, können Empfehlungen erscheinen
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                Task { await loadDiscoveryIfNeeded() }
            }
        }
        .onChange(of: viewModel.results) { _, _ in
            updateResultsModel()
        }
        .onChange(of: selectedSort) { _, _ in
            updateResultsModel()
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            // Wenn der Fokus weg ist und die Suche leer ist, dürfen Inspirationen wieder auftauchen.
            if !focused {
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    Task { await loadDiscoveryIfNeeded() }
                }
            }
        }
        .onChange(of: watchProvidersRegionCode) { _, _ in
            Task { await loadDiscoveryIfNeeded(force: true) }
        }
        .onDisappear {
            cancelSearchTasks()
        }
    }

    // MARK: - Sticky Suchkopf

    private var stickySearchHeader: some View {
        MovieSearchStickyHeaderView(
            query: $query,
            selectedSort: $selectedSort,
            headerTopSpacer: headerTopSpacer,
            isLoading: viewModel.isLoading,
            resultsCount: viewModel.results.count,
            totalResults: viewModel.totalResults,
            keyboardAnimationDuration: keyboard.animationDuration,
            isSearchFieldFocused: isSearchFieldFocused,
            focusBinding: $isSearchFieldFocused,
            onSubmit: {
                startSearch(reset: true)
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