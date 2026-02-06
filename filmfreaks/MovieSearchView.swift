//
//  MovieSearchView.swift
//  filmfreaks
//

internal import SwiftUI
import Combine
internal import UIKit
internal import VisionKit

// MARK: - MovieSearchView

struct MovieSearchView: View {


    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var displaySettings: DisplaySettings

    // Keyboard (gegen Content-Jump beim Fokus)
    @StateObject var keyboard = KeyboardMonitor()

    // Suche
    @State var query: String = ""
    @State var isLoading: Bool = false
    @State private var errorMessage: String?
    @State var results: [TMDbMovieResult] = []

    // Pagination
    @State var currentPage: Int = 1
    @State var totalPages: Int = 1
    @State private var totalResults: Int = 0
    @State var isLoadingMore: Bool = false

    // Sortierung
    @State var selectedSort: MovieSearchSortOption = .relevance

    // Detail-Sheet
    @State private var detailResult: TMDbMovieResult?
    @State private var showingDetail: Bool = false

    // Toast
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // Markierung: schon in Listen
    @State private var localWatchedKeys: Set<String>
    @State private var localBacklogKeys: Set<String>

    // NEU: Such-Historie
    @State private var recentQueries: [String] = SearchHistoryManager.load()

    // Skeleton-Pulsing
    @State private var skeletonPulse: Bool = false

    // Medium scannen (Live Text)
    @State private var showScanner: Bool = false
    @State private var scannerError: String?
    @State private var showScannerError: Bool = false

    // NEU: Kandidatenhilfe nach Scan
    @State private var scannerCandidates: [String] = []
    @State private var candidatePickerItems: [String] = []
    @State private var showCandidatePicker: Bool = false
    @State private var lastTappedScanText: String?

    // Optional: Focus fürs Suchfeld (bei „Manuell bearbeiten“)
    @FocusState var isSearchFieldFocused: Bool

    // ✅ NEU: Empfehlungen (Inspiration)
    @State private var recommendations: [TMDbMovieResult] = []
    @State private var isLoadingRecommendations: Bool = false
    @State private var recommendationsError: String?
    @State private var recommendationsSeedTitle: String?
    @State private var recommendationsLastUpdated: Date?

    private let recommendationsCacheMaxAge: TimeInterval = 60 * 60 * 24 // 24h
    private let recommendationsFallbackToPopularIfNoSeeds: Bool = true

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
            initialValue: Set(existingWatched.map { MovieSearchView.keyFor(movie: $0) })
        )
        _localBacklogKeys = State(
            initialValue: Set(existingBacklog.map { MovieSearchView.keyFor(movie: $0) })
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
                                let key = keyFor(result: result)
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
                                        let movie = convertToMovie(result)
                                        onAddToWatched(movie)
                                        localWatchedKeys.insert(key)
                                        showConfirmation("Zu „Gesehen“ hinzugefügt")
                                    },
                                    onAddToBacklog: {
                                        let movie = convertToMovie(result)
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
                                let key = keyFor(result: result)
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
                                        let movie = convertToMovie(result)
                                        onAddToWatched(movie)
                                        localWatchedKeys.insert(key)
                                        showConfirmation("Zu „Gesehen“ hinzugefügt")
                                    },
                                    onAddToBacklog: {
                                        let movie = convertToMovie(result)
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
                let key = keyFor(result: result)
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

                            let ranked = rankedCandidates(from: scannerCandidates, tapped: scanned)

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
                NavigationStack {
                    List {
                        if let tapped = lastTappedScanText?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !tapped.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Du hast angetippt:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(tapped)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(3)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Section("Erkannten Titel auswählen") {
                            if candidatePickerItems.isEmpty {
                                Text("Keine brauchbaren Vorschläge erkannt. Tippe auf „Manuell bearbeiten“.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(candidatePickerItems, id: \.self) { candidate in
                                    Button {
                                        showCandidatePicker = false
                                        query = candidate
                                        Task { await performSearch(reset: true) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(candidate)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text("Suche starten")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        Section {
                            Button {
                                // Best effort: nimm Top-Kandidat (oder tapped) rein, aber starte NICHT automatisch
                                let fallback = candidatePickerItems.first
                                    ?? lastTappedScanText
                                    ?? ""

                                query = cleanupCandidate(fallback)
                                showCandidatePicker = false

                                // Fokus ins Suchfeld
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isSearchFieldFocused = true
                                }
                            } label: {
                                Label("Manuell bearbeiten", systemImage: "pencil")
                            }
                        }
                    }
                    .navigationTitle("Scan-Vorschläge")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                showCandidatePicker = false
                            }
                        }
                    }
                }
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

    private func clearSearch() {
        query = ""
        results = []
        errorMessage = nil
        currentPage = 1
        totalPages = 1
        totalResults = 0
        selectedSort = .relevance
        // Verlauf bleibt erhalten
    }

    private func handleScanTap() {
        if #available(iOS 16.0, *) {
            guard DataScannerViewController.isSupported else {
                scannerError = "Scanner wird auf diesem Gerät nicht unterstützt."
                showScannerError = true
                return
            }
            guard DataScannerViewController.isAvailable else {
                scannerError = "Scanner ist gerade nicht verfügbar (Kamera/Permission?)."
                showScannerError = true
                return
            }

            // Kandidaten zurücksetzen, damit kein „Altbestand“ reinfunkt
            scannerCandidates = []
            candidatePickerItems = []
            lastTappedScanText = nil

            showScanner = true
        } else {
            scannerError = "„Medium scannen“ benötigt iOS 16 oder neuer."
            showScannerError = true
        }
    }

    private func openDetail(_ result: TMDbMovieResult) {
        detailResult = result
        showingDetail = true
    }

    // MARK: - Toast

    private func showConfirmation(_ text: String) {
        toastMessage = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.25)) {
                showToast = false
            }
        }
    }
    // MARK: - ✅ Empfehlungen Logik

    private func loadRecommendationsIfNeeded(force: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return }
        // Wenn das Suchfeld gerade Fokus hat, sollen „Inspirationen“ nicht auftauchen (und müssen auch nicht geladen werden).
        guard !isSearchFieldFocused else { return }
        // Nur laden, wenn wir wirklich im Idle-State sind.
        guard results.isEmpty && !isLoading else { return }
        guard !isLoadingRecommendations else { return }

        if !force, let cached = RecommendationsCacheManager.load(maxAge: recommendationsCacheMaxAge) {
            await MainActor.run {
                self.recommendations = cached.results
                self.recommendationsSeedTitle = cached.seedTitle
                self.recommendationsLastUpdated = cached.timestamp
                self.recommendationsError = nil
            }
            return
        }

        let seeds = recommendationSeedMovies()
        if seeds.isEmpty && !recommendationsFallbackToPopularIfNoSeeds {
            await MainActor.run {
                self.recommendations = []
                self.recommendationsSeedTitle = nil
                self.recommendationsLastUpdated = nil
                self.recommendationsError = "Noch keine geeigneten „Gesehen“-Filme mit TMDb-ID gefunden."
            }
            RecommendationsCacheManager.clear()
            return
        }

        await MainActor.run {
            self.isLoadingRecommendations = true
            self.recommendationsError = nil
        }

        do {
            let existingKeys = localWatchedKeys.union(localBacklogKeys)

            var aggregated: [TMDbMovieResult] = []
            let seedTitle: String? = seeds.first?.title

            if seeds.isEmpty {
                // ✅ Fallback: wenn noch keine Seeds da sind, zeig „Beliebt auf TMDb“
                let response = try await TMDbAPI.shared.fetchPopularMovies(page: 1)
                aggregated = response.results
            } else {
                // bewusst klein halten: 3 Seeds = 3 Requests, meist reicht das
                for seed in seeds.prefix(3) {
                    guard let tmdbId = seed.tmdbId else { continue }
                    let response = try await TMDbAPI.shared.fetchMovieRecommendations(id: tmdbId, page: 1)
                    aggregated.append(contentsOf: response.results)
                    if aggregated.count >= 80 { break }
                }
            }

            // Fallback: wenn recommendations leer sind, probieren wir „similar“ für den ersten Seed
            if aggregated.isEmpty, let firstId = seeds.first?.tmdbId {
                let response = try await TMDbAPI.shared.fetchMovieSimilar(id: firstId, page: 1)
                aggregated = response.results
            }

            // Dedupe + nicht schon in Listen + limit
            var seen = Set<Int>()
            var filtered: [TMDbMovieResult] = []

            for r in aggregated {
                if seen.contains(r.id) { continue }
                seen.insert(r.id)

                let key = keyFor(result: r)
                if existingKeys.contains(key) { continue }

                filtered.append(r)
                if filtered.count >= 20 { break }
            }

            await MainActor.run {
                self.recommendations = filtered
                self.recommendationsSeedTitle = seedTitle
                self.recommendationsLastUpdated = Date()
                self.isLoadingRecommendations = false
            }

            RecommendationsCacheManager.save(seedTitle: seedTitle, results: filtered)

        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.recommendationsError = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoadingRecommendations = false
            }
        } catch {
            await MainActor.run {
                self.recommendationsError = "Konnte keine Empfehlungen laden. Bitte später nochmal versuchen."
                self.isLoadingRecommendations = false
            }
        }
    }

    private func recommendationSeedMovies() -> [Movie] {
        let candidates = existingWatched.filter { $0.tmdbId != nil }
        guard !candidates.isEmpty else { return [] }

        // 1) „Zuletzt gesehen“
        let recentSorted = candidates.sorted {
            ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast)
        }
        let recentSeeds = Array(recentSorted.prefix(3))

        // 2) „Höchste eigene Bewertung“ (best effort; siehe ownRatingBestEffort)
        let ratedSeeds: [Movie] = candidates
            .compactMap { movie -> (Movie, Double)? in
                guard let r = ownRatingBestEffort(for: movie) else { return nil }
                return (movie, r)
            }
            .sorted { a, b in
                if a.1 == b.1 {
                    // stabil: bei gleicher Bewertung zuletzt gesehen zuerst
                    return (a.0.watchedDate ?? .distantPast) > (b.0.watchedDate ?? .distantPast)
                }
                return a.1 > b.1
            }
            .map { $0.0 }

        // Mix: abwechselnd recent / rated, dedupe per TMDb-ID (Fallback: title|year)
        var mixed: [Movie] = []
        var seenTMDbIds = Set<Int>()
        var seenKeys = Set<String>()

        func add(_ movie: Movie) {
            if let id = movie.tmdbId {
                if seenTMDbIds.contains(id) { return }
                seenTMDbIds.insert(id)
            } else {
                let k = MovieSearchView.keyFor(movie: movie)
                if seenKeys.contains(k) { return }
                seenKeys.insert(k)
            }
            mixed.append(movie)
        }

        let maxCount = max(recentSeeds.count, ratedSeeds.count)
        for i in 0..<maxCount {
            if i < recentSeeds.count { add(recentSeeds[i]) }
            if i < ratedSeeds.count { add(ratedSeeds[i]) }
            if mixed.count >= 5 { break }
        }

        // Falls noch nicht genug: mit „recent“ auffüllen (stabil, predictable)
        if mixed.count < 5 {
            for m in recentSorted {
                add(m)
                if mixed.count >= 5 { break }
            }
        }

        // 5 Seeds reichen; wir nehmen später sowieso nur 3 Requests
        return Array(mixed.prefix(5))
    }

    /// Best-effort Ermittlung der „eigenen“ Bewertung, ohne deine Model-Types hart zu referenzieren.
    /// - 1) Versucht direkte Felder am `Movie` (z.B. myRating/ownRating/personalRating/userRating…)
    /// - 2) Fällt auf `ratings` zurück (sucht nach Own-Flag; sonst nimmt es das Maximum, besser als nix)
    private func ownRatingBestEffort(for movie: Movie) -> Double? {
        // 1) Direkt am Movie
        let directKeys = [
            "myRating", "ownRating", "personalRating", "userRating",
            "personalScore", "myScore"
        ]
        for key in directKeys {
            if let raw = reflectedValue(named: key, in: movie),
               let num = extractNumeric(raw) {
                return num
            }
        }

        // 2) ratings-Array am Movie
        guard let ratingsRaw = reflectedValue(named: "ratings", in: movie) else { return nil }
        guard let arr = ratingsRaw as? [Any] else { return nil }

        let ownFlags = ["isOwn", "isMine", "isMe", "isCurrentUser", "isUser", "isSelf"]
        let valueKeys = ["rating", "score", "value", "points"]

        // 2a) Own-Flag suchen
        for item in arr {
            for flag in ownFlags {
                if let fv = reflectedValue(named: flag, in: item),
                   let b = fv as? Bool,
                   b == true {
                    for vk in valueKeys {
                        if let vv = reflectedValue(named: vk, in: item),
                           let num = extractNumeric(vv) {
                            return num
                        }
                    }
                }
            }
        }

        // 2b) Kein Own-Flag gefunden → nimm das höchste, das wir finden (Fallback)
        var best: Double?
        for item in arr {
            for vk in valueKeys {
                if let vv = reflectedValue(named: vk, in: item),
                   let num = extractNumeric(vv) {
                    best = max(best ?? num, num)
                }
            }
        }
        return best
    }

    private func reflectedValue(named name: String, in any: Any) -> Any? {
        for child in Mirror(reflecting: any).children {
            if child.label == name { return child.value }
        }
        return nil
    }

    private func extractNumeric(_ any: Any) -> Double? {
        switch any {
        case let d as Double: return d
        case let f as Float: return Double(f)
        case let i as Int: return Double(i)
        case let i as Int16: return Double(i)
        case let i as Int32: return Double(i)
        case let i as Int64: return Double(i)
        case let u as UInt: return Double(u)
        case let u as UInt16: return Double(u)
        case let u as UInt32: return Double(u)
        case let u as UInt64: return Double(u)
        case let s as String:
            // „7,5“ → 7.5
            return Double(s.replacingOccurrences(of: ",", with: "."))
        default:
            return nil
        }
    }
    // MARK: - Suche

    private func performSearch(reset: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if reset {
            await MainActor.run {
                results = []
                currentPage = 1
                totalPages = 1
                totalResults = 0
                selectedSort = .relevance
                errorMessage = nil
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await TMDbAPI.shared.searchMoviesPaged(query: trimmed, page: 1)

            // Suchbegriff in Verlauf speichern
            SearchHistoryManager.add(query: trimmed)
            let updatedHistory = SearchHistoryManager.load()

            await MainActor.run {
                self.results = response.results
                self.currentPage = response.page
                self.totalPages = response.total_pages
                self.totalResults = response.total_results
                self.isLoading = false
                self.recentQueries = updatedHistory
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler bei der Suche. Bitte später nochmal versuchen."
                self.isLoading = false
            }
        }
    }

    private func loadMore() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard currentPage < totalPages else { return }
        guard !isLoadingMore else { return }

        isLoadingMore = true
        do {
            let nextPage = currentPage + 1
            let response = try await TMDbAPI.shared.searchMoviesPaged(query: trimmed, page: nextPage)

            await MainActor.run {
                // Dupe-Schutz per TMDb ID
                let existingIds = Set(self.results.map { $0.id })
                let newOnes = response.results.filter { !existingIds.contains($0.id) }
                self.results.append(contentsOf: newOnes)

                self.currentPage = response.page
                self.totalPages = response.total_pages
                self.totalResults = response.total_results
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
                self.errorMessage = "Konnte nicht mehr laden. Bitte später nochmal versuchen."
            }
        }
    }

    // MARK: - Scan-Kandidaten (NEU)

    private func rankedCandidates(from recognized: [String], tapped: String) -> [String] {
        var all: [String] = []

        // Tap-Text rein (inkl. Zeilen)
        all.append(tapped)
        all.append(contentsOf: tapped.components(separatedBy: .newlines))

        // Alle erkannten Texte
        all.append(contentsOf: recognized)

        // Cleanup + dedupe
        var cleaned: [String] = all
            .map { cleanupCandidate($0) }
            .filter { !$0.isEmpty }

        // Dedupe (case-insensitive)
        var seen = Set<String>()
        cleaned = cleaned.filter { s in
            let k = s.lowercased()
            if seen.contains(k) { return false }
            seen.insert(k)
            return true
        }

        // Scoring + sort
        let scored = cleaned
            .map { ($0, scoreCandidate($0)) }
            .filter { $0.1 > -20 } // raus mit dem offensichtlichen Müll

        let sorted = scored
            .sorted { a, b in
                if a.1 == b.1 { return a.0.count > b.0.count }
                return a.1 > b.1
            }
            .map { $0.0 }

        // Top N – reicht in der Praxis
        return Array(sorted.prefix(12))
    }

    private func cleanupCandidate(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // häufige „Deko“-Zeichen entfernen
        t = t.replacingOccurrences(of: "•", with: " ")
        t = t.replacingOccurrences(of: "·", with: " ")
        t = t.replacingOccurrences(of: "|", with: " ")
        t = t.replacingOccurrences(of: "—", with: " ")
        t = t.replacingOccurrences(of: "–", with: " ")

        // Mehrfachspaces zu einem
        while t.contains("  ") {
            t = t.replacingOccurrences(of: "  ", with: " ")
        }

        // Trim nochmal
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t-_:;,.()[]{}\"'"))

        // Zu kurz? Weg
        if t.count < 3 { return "" }

        return t
    }

    private func scoreCandidate(_ s: String) -> Int {
        let upper = s.uppercased()

        // absolute No-Gos / Buzzwords
        let badTokens: [String] = [
            "BLU-RAY", "BLURAY", "DVD", "4K", "UHD", "ULTRA HD",
            "SPECIAL EDITION", "LIMITED EDITION", "COLLECTOR", "COLLECTORS", "STEELBOOK",
            "DIGITAL COPY", "DIGITAL", "BONUS", "FEATURES", "DISC", "DISCS",
            "DOLBY", "ATMOS", "DTS", "HDR",
            "FSK", "REGION", "UNCUT", "DIRECTOR", "DIRECTOR'S", "CUT", "EXTENDED"
        ]

        var score = 0

        // Länge – Film-Titel liegen oft irgendwo 8–40 Zeichen
        switch s.count {
        case 8...40: score += 30
        case 5...80: score += 12
        default: score -= 10
        }

        // Mehrteilig (Spaces) ist oft Titel, Einzelwort ist oft Logo/Buzzword
        if s.contains(" ") { score += 10 } else { score -= 4 }

        // Buchstabenanteil
        let letters = s.filter { $0.isLetter }.count
        if letters >= 4 { score += 10 } else { score -= 8 }

        // Ziffern-only? Nope.
        let digits = s.filter { $0.isNumber }.count
        if digits == s.count { score -= 50 }
        if digits > 0 && digits > letters { score -= 10 }

        // Bad token penalty (stark)
        if badTokens.contains(where: { upper.contains($0) }) {
            score -= 40
        }

        // sehr „shouty“ kurze Uppercase Wörter: BLU-RAY / DVD / UHD etc.
        if s.count <= 12, !s.contains(" "), s == upper {
            score -= 12
        }

        return score
    }
    // MARK: - Hilfsfunktionen

    func releaseYear(from dateString: String?) -> String? {
        guard
            let dateString,
            dateString.count >= 4
        else { return nil }
        return String(dateString.prefix(4))
    }

    func yearInt(from dateString: String?) -> Int? {
        guard let y = releaseYear(from: dateString) else { return nil }
        return Int(y)
    }

    // Schlüssel, um konsistent zu erkennen, ob ein Film schon in einer Liste ist
    private static func keyFor(movie: Movie) -> String {
        (movie.title.lowercased()) + "|" + movie.year
    }

    private func keyFor(result: TMDbMovieResult) -> String {
        let year = releaseYear(from: result.release_date) ?? "n/a"
        return result.title.lowercased() + "|" + year
    }


    private func convertToMovie(_ result: TMDbMovieResult) -> Movie {
        let year = releaseYear(from: result.release_date) ?? "n/a"
        return Movie(
            title: result.title,
            year: year,
            tmdbRating: result.vote_average,
            ratings: [],
            posterPath: result.poster_path,
            tmdbId: result.id
        )
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