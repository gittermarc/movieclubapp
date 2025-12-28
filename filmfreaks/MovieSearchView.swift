//
//  MovieSearchView.swift
//  filmfreaks
//

internal import SwiftUI
internal import VisionKit

// MARK: - Such-Historie (lokal per UserDefaults)

fileprivate struct SearchHistoryManager {
    private static let key = "MovieSearchHistory"
    private static let maxEntries = 15

    static func load() -> [String] {
        (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
    }

    static func save(_ entries: [String]) {
        UserDefaults.standard.set(entries, forKey: key)
    }

    static func add(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var current = load()

        // Dedupe (case-insensitive): vorhandenen Eintrag entfernen
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }

        // Neuestes vorne einfügen
        current.insert(trimmed, at: 0)

        // Begrenzen
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }

        save(current)
    }

    static func clear() {
        save([])
    }
}

// MARK: - Sortierung (Search)

fileprivate enum MovieSearchSortOption: String, CaseIterable, Identifiable {
    case relevance = "Relevanz"
    case titleAZ = "Titel A–Z"
    case titleZA = "Titel Z–A"
    case yearNewest = "Jahr (neu → alt)"
    case yearOldest = "Jahr (alt → neu)"
    case ratingHigh = "TMDb Rating (hoch)"
    case ratingLow = "TMDb Rating (niedrig)"

    var id: Self { self }
}

// MARK: - MovieSearchView

struct MovieSearchView: View {

    private enum UI {
        static let posterWidth: CGFloat = 76
        static let posterHeight: CGFloat = 114 // ~2:3
        static let cardCorner: CGFloat = 14
    }

    @Environment(\.dismiss) private var dismiss

    // Suche
    @State private var query: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var results: [TMDbMovieResult] = []

    // Pagination
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var totalResults: Int = 0
    @State private var isLoadingMore: Bool = false

    // Sortierung
    @State private var selectedSort: MovieSearchSortOption = .relevance

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

    // NEU: Medium scannen (Live Text)
    @State private var showScanner: Bool = false
    @State private var scannerError: String?
    @State private var showScannerError: Bool = false

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
                    // NEU: Zuletzt gesucht – nur wenn noch nichts eingegeben ist
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !recentQueries.isEmpty {
                        recentQueriesView
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
                                        .background(Color.blue.opacity(0.12))
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
                        }
                    } else if !isLoading && query.isEmpty && recentQueries.isEmpty {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            // Sticky Header (Material + Linear Loader + Sort/Counter)
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
            // NEU: Scanner-Sheet
            .sheet(isPresented: $showScanner) {
                if #available(iOS 16.0, *) {
                    MediaTitleScannerView(
                        onPickText: { scanned in
                            // häufig: mehrere Zeilen; wir nehmen die erste brauchbare
                            let cleaned = scanned
                                .components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .first(where: { !$0.isEmpty }) ?? scanned

                            showScanner = false
                            query = cleaned

                            Task { await performSearch(reset: true) }
                        },
                        onCancel: {
                            showScanner = false
                        }
                    )
                } else {
                    Text("„Medium scannen“ benötigt iOS 16 oder neuer.")
                        .padding()
                }
            }
            // NEU: Scanner-Fehler
            .alert("Medium scannen", isPresented: $showScannerError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scannerError ?? "Unbekannter Fehler.")
            }
            // 👇 Toast-Overlay unten
            .overlay(alignment: .bottom) {
                if showToast, let toastMessage {
                    toastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Derived

    private var canLoadMore: Bool {
        currentPage < totalPages
        && !isLoading
        && !isLoadingMore
        && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sortedResults: [TMDbMovieResult] {
        switch selectedSort {
        case .relevance:
            // TMDb-Reihenfolge, wie geliefert
            return results

        case .titleAZ:
            return results.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        case .titleZA:
            return results.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }

        case .yearNewest:
            return results.sorted { (yearInt(from: $0.release_date) ?? -1) > (yearInt(from: $1.release_date) ?? -1) }

        case .yearOldest:
            return results.sorted { (yearInt(from: $0.release_date) ?? Int.max) < (yearInt(from: $1.release_date) ?? Int.max) }

        case .ratingHigh:
            return results.sorted { $0.vote_average > $1.vote_average }

        case .ratingLow:
            return results.sorted { $0.vote_average < $1.vote_average }
        }
    }

    // MARK: - Sticky Suchkopf

    private var stickySearchHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Filmtitel suchen…", text: $query)
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

            // NEU: Medium scannen Button
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
                    .background(Color.blue.opacity(0.12))
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

    // MARK: - Ergebnis-Karte (Tap -> Details, + Menu -> Add)

    @ViewBuilder
    private func resultCard(for result: TMDbMovieResult) -> some View {
        let key = keyFor(result: result)
        let isInWatched = localWatchedKeys.contains(key)
        let isInBacklog = localBacklogKeys.contains(key)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {

                // ✅ Content als Button: nimmt den verfügbaren Platz, Menu sitzt daneben (kein Overlap mehr)
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
                                .background(Color.blue.opacity(0.08))
                                .clipShape(Capsule())
                            }

                            // ✅ subtiler Chevron + Material-Glow statt „Tippen für Details“
                            detailsHintChip
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // + Menu (Add / Details) – sitzt jetzt als eigene Spalte, kollidiert nicht mit dem Titel
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

    // ✅ neuer „Details“-Chip (Chevron + Material-Glow)
    private var detailsHintChip: some View {
        HStack(spacing: 6) {
            Text("Details")
                .font(.caption.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color.blue.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: Color.blue.opacity(0.14), radius: 10, x: 0, y: 2)   // „Glow“, aber subtil
        .shadow(color: Color.blue.opacity(0.08), radius: 18, x: 0, y: 8)   // weicher Nachglow
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
        // Nach kurzer Zeit wieder ausblenden
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

            // NEU: Suchbegriff in Verlauf speichern
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
                self.errorMessage = "TMDb API-Key fehlt. Bitte in TMDbAPI.swift eintragen."
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

    // MARK: - Hilfsfunktionen

    private func releaseYear(from dateString: String?) -> String? {
        guard
            let dateString,
            dateString.count >= 4
        else { return nil }
        return String(dateString.prefix(4))
    }

    private func yearInt(from dateString: String?) -> Int? {
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

                AsyncImage(
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
