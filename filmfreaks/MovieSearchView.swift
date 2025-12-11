//
//  MovieSearchView.swift
//  filmfreaks
//

internal import SwiftUI

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

// MARK: - MovieSearchView

struct MovieSearchView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    // Suche
    @State private var query: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var results: [TMDbMovieResult] = []
    
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
                    // Suchfeld + Status
                    searchHeader
                    
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
                    
                    if results.isEmpty && !isLoading && !query.isEmpty {
                        Text("Keine Ergebnisse gefunden.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    
                    if !results.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                                    resultCard(for: result)
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
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
                }
            }
            .navigationTitle("Film suchen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
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
    
    // MARK: - Suchkopf
    
    private var searchHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Filmtitel suchen…", text: $query)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await performSearch()
                            }
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            errorMessage = nil
                            // Verlauf bleibt erhalten
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if isLoading {
                    ProgressView()
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal)
            
            if !results.isEmpty {
                HStack {
                    Text("\(results.count) Treffer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - „Zuletzt gesucht“-View
    
    private var recentQueriesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Zuletzt gesucht")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(recentQueries, id: \.self) { term in
                    Button {
                        query = term
                        Task {
                            await performSearch()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption2)
                            Text(term)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    // MARK: - Ergebnis-Karte
    
    @ViewBuilder
    private func resultCard(for result: TMDbMovieResult) -> some View {
        let key = keyFor(result: result)
        let isInWatched = localWatchedKeys.contains(key)
        let isInBacklog = localBacklogKeys.contains(key)
        
        VStack(alignment: .leading, spacing: 10) {
            // Kopf mit Poster + Info
            HStack(alignment: .top, spacing: 12) {
                posterThumbnail(for: result)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(result.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        // Markierung, wenn schon in Listen
                        if isInWatched || isInBacklog {
                            HStack(spacing: 4) {
                                if isInWatched {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                    Text("In „Gesehen“")
                                        .font(.caption2)
                                }
                                if isInBacklog {
                                    if isInWatched { Text("·").font(.caption2) }
                                    Image(systemName: "tray.full.fill")
                                        .font(.caption)
                                    Text("Im Backlog")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                    
                    if let year = releaseYear(from: result.release_date) {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(String(format: "TMDb: %.1f / 10", result.vote_average))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        detailResult = result
                        showingDetail = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Details & Trailer anzeigen")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding(.top, 4)
                }
            }
            
            // Buttons: direkt hinzufügen
            HStack(spacing: 8) {
                Button {
                    let movie = convertToMovie(result)
                    onAddToWatched(movie)
                    localWatchedKeys.insert(key)
                    showConfirmation("Zu „Gesehen“ hinzugefügt")
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(isInWatched ? "Schon in Gesehen" : "Zu gesehen")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isInWatched
                        ? Color.green.opacity(0.10)
                        : Color.green.opacity(0.18)
                    )
                    .foregroundStyle(isInWatched ? Color.secondary : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isInWatched)
                
                Button {
                    let movie = convertToMovie(result)
                    onAddToBacklog(movie)
                    localBacklogKeys.insert(key)
                    showConfirmation("Zum Backlog hinzugefügt")
                } label: {
                    HStack {
                        Image(systemName: "text.badge.plus")
                        Text(isInBacklog ? "Schon im Backlog" : "In Backlog")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isInBacklog
                        ? Color.blue.opacity(0.08)
                        : Color.blue.opacity(0.15)
                    )
                    .foregroundStyle(isInBacklog ? Color.secondary : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isInBacklog)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedResults = try await TMDbAPI.shared.searchMovies(query: trimmed)
            
            // NEU: Suchbegriff in Verlauf speichern
            SearchHistoryManager.add(query: trimmed)
            let updatedHistory = SearchHistoryManager.load()
            
            await MainActor.run {
                self.results = fetchedResults
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
    
    // MARK: - Hilfsfunktionen
    
    private func releaseYear(from dateString: String?) -> String? {
        guard
            let dateString,
            dateString.count >= 4
        else { return nil }
        return String(dateString.prefix(4))
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
        if let path = result.poster_path,
           let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
            
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
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .clipped()
            
        } else {
            Rectangle()
                .foregroundStyle(.gray.opacity(0.1))
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
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
