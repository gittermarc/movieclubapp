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

    private enum UI {
        static let posterWidth: CGFloat = 76
        static let posterHeight: CGFloat = 114 // ~2:3
        static let cardCorner: CGFloat = 14

        // Empfehlungen
        static let recPosterWidth: CGFloat = 120
        static let recPosterHeight: CGFloat = 178 // ~2:3
        static let recCardCorner: CGFloat = 16
    }

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
                // Hintergrund
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Zuletzt gesucht – nur wenn noch nichts eingegeben ist
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !recentQueries.isEmpty {
                        recentQueriesView
                    }

                    // ✅ Inspiration (nur wenn Suche leer & keine Ergebnisse gerendert werden)
                    if shouldShowRecommendations {
                        recommendationsView
                    }

                    // Fehler / leere Zustände
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Skeletons (während initialer Suche)
                    if isLoading && results.isEmpty {
                        skeletonResultsView
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                    skeletonPulse.toggle()
                                }
                            }
                    } else if results.isEmpty && !isLoading && !query.isEmpty {
                        Text("Keine Ergebnisse gefunden.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else if !sortedResults.isEmpty {
                        let displayed = sortedResults

                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(displayed) { result in
                                    resultCard(for: result)
                                        .onAppear {
                                            // Infinite Scroll: wenn das letzte Element auftaucht -> laden
                                            if displayed.last?.id == result.id, canLoadMore {
                                                Task { await loadMore() }
                                            }
                                        }
                                }

                                // Footer: Loading / Mehr laden (Fallback)
                                if isLoadingMore {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("Lade weitere Treffer…")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 14)
                                } else if canLoadMore {
                                    Button {
                                        Task { await loadMore() }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.down.circle")
                                            Text("Mehr laden")
                                        }
                                        .font(.footnote.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(displaySettings.tintSoftBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 6)
                                    .padding(.bottom, 12)
                                } else if totalResults > 0 {
                                    Text("Ende der Trefferliste.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .padding(.bottom, keyboard.height)
                            .animation(.easeOut(duration: keyboard.animationDuration), value: keyboard.height)
                        }
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
                    toastView(message: toastMessage)
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
        VStack(spacing: 10) {

            // ✅ Platzhalter, damit das Suchfeld beim Fokus nicht unter den Inline-Titel rutscht
            Color.clear
                .frame(height: headerTopSpacer)
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Filmtitel suchen…", text: $query)
                        .focused($isSearchFieldFocused)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await performSearch(reset: true) }
                        }

                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            errorMessage = nil
                            currentPage = 1
                            totalPages = 1
                            totalResults = 0
                            selectedSort = .relevance
                            // Verlauf bleibt erhalten
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if isLoading {
                    ProgressView()
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal)

            // Medium scannen Button
            HStack {
                Button {
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
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                        Text("Medium scannen")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(displaySettings.tintSoftBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
            }

            if !results.isEmpty {
                HStack {
                    Text("\(results.count) von \(totalResults) Treffer")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(MovieSearchSortOption.allCases) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                if selectedSort == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                            Text(selectedSort.rawValue)
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
        .animation(.easeOut(duration: keyboard.animationDuration), value: isSearchFieldFocused)
    }

    // MARK: - „Zuletzt gesucht“-View (horizontal)

    private var recentQueriesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Zuletzt gesucht")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !recentQueries.isEmpty {
                    Button {
                        SearchHistoryManager.clear()
                        recentQueries = []
                    } label: {
                        Text("Verlauf löschen")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentQueries, id: \.self) { term in
                        Button {
                            query = term
                            Task { await performSearch(reset: true) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text(term)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    // MARK: - ✅ Empfehlungen UI (Inspiration)

    private var recommendationsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    Text("Inspiration")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Button {
                    Task { await loadRecommendationsIfNeeded(force: true) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Aktualisieren")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(displaySettings.tintSoftBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            if let seed = recommendationsSeedTitle, !seed.isEmpty {
                Text("Basierend auf „\(seed)“ und ähnlichen Filmen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Text("Filme, die zu deinem Geschmack passen könnten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            if isLoadingRecommendations {
                recommendationsSkeletonView
            } else if let err = recommendationsError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            } else if recommendations.isEmpty {
                Text("Noch keine Empfehlungen. Füge erst ein paar Filme zu „Gesehen“ hinzu (mit TMDb-ID), dann wird’s hier spannend. 🍿")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommendations) { result in
                            recommendationCard(for: result)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                }
            }

            if let last = recommendationsLastUpdated, !isLoadingRecommendations, recommendationsError == nil, !recommendations.isEmpty {
                Text("Zuletzt aktualisiert: \(last.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private var recommendationsSkeletonView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.22))
                            .frame(width: UI.recPosterWidth, height: UI.recPosterHeight)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.20))
                            .frame(height: 12)
                            .frame(width: UI.recPosterWidth)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.16))
                            .frame(height: 10)
                            .frame(width: UI.recPosterWidth * 0.7)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: UI.recCardCorner)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .redacted(reason: .placeholder)
                }
            }
            .padding(.horizontal)
        }
        .opacity(skeletonPulse ? 0.55 : 0.85)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                skeletonPulse.toggle()
            }
        }
    }

    @ViewBuilder
    private func recommendationCard(for result: TMDbMovieResult) -> some View {
        let key = keyFor(result: result)
        let isInWatched = localWatchedKeys.contains(key)
        let isInBacklog = localBacklogKeys.contains(key)

        ZStack(alignment: .topTrailing) {
            Button {
                openDetail(result)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    posterRecommendation(for: result)
                        .frame(width: UI.recPosterWidth, height: UI.recPosterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .clipped()

                    Text(result.title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        if let year = releaseYear(from: result.release_date) {
                            Text(year)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(String(format: "%.1f", result.vote_average))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                }
                .frame(width: UI.recPosterWidth, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: UI.recCardCorner)
                        .fill(Color(.secondarySystemBackground))
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    openDetail(result)
                } label: {
                    Label("Details & Trailer", systemImage: "info.circle")
                }

                Divider()

                Button {
                    let movie = convertToMovie(result)
                    onAddToWatched(movie)
                    localWatchedKeys.insert(key)
                    showConfirmation("Zu „Gesehen“ hinzugefügt")
                } label: {
                    Label(isInWatched ? "Schon in „Gesehen“" : "Zu „Gesehen“ hinzufügen", systemImage: "checkmark.circle.fill")
                }
                .disabled(isInWatched)

                Button {
                    let movie = convertToMovie(result)
                    onAddToBacklog(movie)
                    localBacklogKeys.insert(key)
                    showConfirmation("Zum Backlog hinzugefügt")
                } label: {
                    Label(isInBacklog ? "Schon im Backlog" : "Zum Backlog hinzufügen", systemImage: "tray.full.fill")
                }
                .disabled(isInBacklog)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func posterRecommendation(for result: TMDbMovieResult) -> some View {
        Group {
            if let path = result.poster_path,
               let url = URL(string: "https://image.tmdb.org/t/p/w342\(path)") {

                CachedAsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeOut(duration: 0.25))
                ) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.2))

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)

                    case .failure:
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }

                    @unknown default:
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.2))
                    }
                }

            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.12))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
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

    // MARK: - Ergebnis-Karte (Tap -> Details, + Menu -> Add)

    @ViewBuilder
    private func resultCard(for result: TMDbMovieResult) -> some View {
        let key = keyFor(result: result)
        let isInWatched = localWatchedKeys.contains(key)
        let isInBacklog = localBacklogKeys.contains(key)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {

                // Content als Button: nimmt den verfügbaren Platz, Menu sitzt daneben (kein Overlap mehr)
                Button {
                    openDetail(result)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        posterThumbnail(for: result)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.title)
                                .font(.headline)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 10) {
                                if let year = releaseYear(from: result.release_date) {
                                    Label(year, systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Label(String(format: "%.1f / 10", result.vote_average), systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Markierung, wenn schon in Listen
                            if isInWatched || isInBacklog {
                                HStack(spacing: 6) {
                                    if isInWatched {
                                        Label("In „Gesehen“", systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    if isInBacklog {
                                        Label("Im Backlog", systemImage: "tray.full.fill")
                                            .font(.caption2)
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(displaySettings.tintUltraSoftBackground)
                                .clipShape(Capsule())
                            }

                            // subtiler Chevron + Material-Glow statt „Tippen für Details“
                            detailsHintChip
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // + Menu (Add / Details)
                Menu {
                    Button {
                        openDetail(result)
                    } label: {
                        Label("Details & Trailer", systemImage: "info.circle")
                    }

                    Divider()

                    Button {
                        let movie = convertToMovie(result)
                        onAddToWatched(movie)
                        localWatchedKeys.insert(key)
                        showConfirmation("Zu „Gesehen“ hinzugefügt")
                    } label: {
                        Label(isInWatched ? "Schon in „Gesehen“" : "Zu „Gesehen“ hinzufügen", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(isInWatched)

                    Button {
                        let movie = convertToMovie(result)
                        onAddToBacklog(movie)
                        localBacklogKeys.insert(key)
                        showConfirmation("Zum Backlog hinzugefügt")
                    } label: {
                        Label(isInBacklog ? "Schon im Backlog" : "Zum Backlog hinzufügen", systemImage: "tray.full.fill")
                    }
                    .disabled(isInBacklog)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text("Hinzufügen")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: UI.cardCorner)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // „Details“-Chip (Chevron + Material-Glow)
    private var detailsHintChip: some View {
        HStack(spacing: 6) {
            Text("Details")
                .font(.caption.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(displaySettings.tintStroke, lineWidth: 1)
        }
        .shadow(color: displaySettings.tintShadowStrong, radius: 10, x: 0, y: 2)
        .shadow(color: displaySettings.tintShadowSoft, radius: 18, x: 0, y: 8)
    }

    private func openDetail(_ result: TMDbMovieResult) {
        detailResult = result
        showingDetail = true
    }

    // MARK: - Skeletons

    private var skeletonResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.bottom, keyboard.height)
        .animation(.easeOut(duration: keyboard.animationDuration), value: keyboard.height)
        .opacity(skeletonPulse ? 0.55 : 0.85)
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.22))
                    .frame(width: UI.posterWidth, height: UI.posterHeight)

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.22))
                        .frame(height: 14)
                        .frame(maxWidth: 240)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.18))
                        .frame(height: 12)
                        .frame(maxWidth: 160)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.16))
                        .frame(height: 26)
                        .frame(maxWidth: 170)
                        .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: UI.cardCorner)
                .fill(Color(.secondarySystemBackground))
        )
        .redacted(reason: .placeholder)
    }

    // MARK: - Toast

    private func toastView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text(message)
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 5)
    }

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

    @ViewBuilder
    private func posterThumbnail(for result: TMDbMovieResult) -> some View {
        let ratingText = String(format: "%.1f", result.vote_average)

        Group {
            if let path = result.poster_path,
               let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {

                CachedAsyncImage(
                    url: url,
                    transaction: Transaction(animation: .easeOut(duration: 0.25))
                ) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)

                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }

                    @unknown default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: UI.posterWidth, height: UI.posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .clipped()

            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: UI.posterWidth, height: UI.posterHeight)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            // Rating Badge
            Text(ratingText)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(6)
        }
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
}
