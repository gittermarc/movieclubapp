//
//  SearchResultDetailView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct SearchResultDetailView: View {
    
    let result: TMDbMovieResult
    var onAddToWatched: (Movie) -> Void
    var onAddToBacklog: (Movie) -> Void
    
    // Neue Zustände: Ist der Film schon in einer Liste?
    @State private var isInWatched: Bool
    @State private var isInBacklog: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var details: TMDbMovieDetails?
    @State private var isLoading: Bool = false     // ← Start jetzt auf false, wir setzen es in onAppear
    @State private var errorMessage: String?
    
    // Custom init, damit wir den Status von außen übergeben können
    init(
        result: TMDbMovieResult,
        isInitiallyInWatched: Bool,
        isInitiallyInBacklog: Bool,
        onAddToWatched: @escaping (Movie) -> Void,
        onAddToBacklog: @escaping (Movie) -> Void
    ) {
        self.result = result
        self.onAddToWatched = onAddToWatched
        self.onAddToBacklog = onAddToBacklog
        _isInWatched = State(initialValue: isInitiallyInWatched)
        _isInBacklog = State(initialValue: isInitiallyInBacklog)
    }
    
    // MARK: - Zusätzliche Metadaten
    
    private var director: String? {
        details?.credits?.crew.first(where: { ($0.job ?? "").lowercased() == "director" })?.name
    }
    
    private var mainCast: String? {
        guard let cast = details?.credits?.cast, !cast.isEmpty else { return nil }
        let names = cast.prefix(6).map { $0.name }
        return names.joined(separator: ", ")
    }
    
    private var keywordsText: String? {
        guard let all = details?.keywords?.allKeywords, !all.isEmpty else { return nil }
        let names = all.map { $0.name }
        return names.joined(separator: ", ")
    }
    
    private var genreNames: [String] {
        details?.genres?
            .map { $0.name }
            .filter { !$0.isEmpty }
        ?? []
    }
    
    private var trailerURL: URL? {
        guard let videos = details?.videos?.results else { return nil }
        if let trailer = videos.first(where: {
            $0.site.lowercased() == "youtube" &&
            $0.type.lowercased() == "trailer"
        }) {
            return URL(string: "https://www.youtube.com/watch?v=\(trailer.key)")
        }
        return nil
    }
    
    private var runtimeText: String? {
        if let runtime = details?.runtime {
            return "\(runtime) Minuten"
        }
        return nil
    }
    
    private var titleText: String {
        details?.title ?? result.title
    }
    
    private var yearText: String? {
        releaseYear(from: details?.release_date ?? result.release_date)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Leichter Verlauf wie in der Suche
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Lade Filmdetails …")
                            .font(.subheadline)
                    }
                    .padding()
                }
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Poster
                        if let url = posterURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        Rectangle()
                                            .foregroundStyle(.gray.opacity(0.2))
                                        ProgressView()
                                    }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    placeholderPoster
                                @unknown default:
                                    placeholderPoster
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .background(Color.black.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            placeholderPoster
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        // Titel & Basisinfos in Card
                        section {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(titleText)
                                    .font(.title2.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if let yearText {
                                    Text("Jahr: \(yearText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack(spacing: 8) {
                                    Text(String(format: "TMDb: %.1f / 10", details?.vote_average ?? result.vote_average))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    if let runtimeText {
                                        Text("• \(runtimeText)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Infos zum Film (Genres, Regie, Cast, Keywords, Trailer)
                        if runtimeText != nil || director != nil || mainCast != nil || keywordsText != nil || !genreNames.isEmpty || trailerURL != nil {
                            section(title: "Infos zum Film") {
                                VStack(alignment: .leading, spacing: 8) {
                                    
                                    // Genres als Chips
                                    if !genreNames.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Genre")
                                                .font(.subheadline).bold()
                                            
                                            LazyVGrid(
                                                columns: [GridItem(.adaptive(minimum: 80), spacing: 8)],
                                                alignment: .leading,
                                                spacing: 8
                                            ) {
                                                ForEach(genreNames, id: \.self) { genre in
                                                    Text(genre)
                                                        .font(.caption)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .background(Color.blue.opacity(0.1))
                                                        .foregroundStyle(.primary)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                    }
                                    
                                    if let director {
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text("Regie:")
                                                .font(.subheadline).bold()
                                            Text(director)
                                                .font(.subheadline)
                                        }
                                    }
                                    
                                    if let mainCast {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Hauptdarsteller")
                                                .font(.subheadline).bold()
                                            Text(mainCast)
                                                .font(.subheadline)
                                        }
                                    }
                                    
                                    if let keywordsText {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Schlüsselwörter")
                                                .font(.subheadline).bold()
                                            Text(keywordsText)
                                                .font(.subheadline)
                                        }
                                    }
                                    
                                    if let trailerURL {
                                        Link(destination: trailerURL) {
                                            HStack {
                                                Image(systemName: "play.rectangle.fill")
                                                Text("Trailer auf YouTube")
                                            }
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        
                        // Beschreibung
                        section(title: "Beschreibung") {
                            if let overview = details?.overview, !overview.isEmpty {
                                Text(overview)
                                    .font(.body)
                            } else {
                                Text("Keine Beschreibung verfügbar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // Hinzufügen zu Listen
                        section(title: "Zu deiner Liste hinzufügen") {
                            if isInWatched || isInBacklog {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                    if isInWatched && isInBacklog {
                                        Text("Dieser Film ist bereits in „Gesehen“ und im Backlog.")
                                    } else if isInWatched {
                                        Text("Dieser Film ist bereits in deiner „Gesehen“-Liste.")
                                    } else if isInBacklog {
                                        Text("Dieser Film ist bereits in deinem Backlog.")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Button {
                                    let movie = createMovie()
                                    onAddToWatched(movie)
                                    isInWatched = true
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(isInWatched ? "Schon in Gesehen" : "Zu gesehen hinzufügen")
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        isInWatched
                                        ? Color.green.opacity(0.10)
                                        : Color.green.opacity(0.18)
                                    )
                                    .foregroundStyle(isInWatched ? Color.secondary : Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isInWatched)
                                
                                Button {
                                    let movie = createMovie()
                                    onAddToBacklog(movie)
                                    isInBacklog = true
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "text.badge.plus")
                                        Text(isInBacklog ? "Schon im Backlog" : "In Backlog speichern")
                                    }
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        isInBacklog
                                        ? Color.blue.opacity(0.08)
                                        : Color.blue.opacity(0.15)
                                    )
                                    .foregroundStyle(isInBacklog ? Color.secondary : Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isInBacklog)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(result.title)
        .navigationBarTitleDisplayMode(.inline)
        // WICHTIG: statt .task jetzt onAppear + onChange
        .onAppear {
            // Beim ersten Anzeigen für dieses Result laden
            if details == nil {
                isLoading = true
                errorMessage = nil
                Task {
                    await loadDetails()
                }
            }
        }
        .onChange(of: result.id) { _, _ in
            // Falls SwiftUI die View mal mit einem anderen Result wiederverwendet
            isLoading = true
            errorMessage = nil
            details = nil
            Task {
                await loadDetails()
            }
        }
    }
    
    // MARK: - Helper
    
    private var posterURL: URL? {
        let path = details?.poster_path ?? result.poster_path
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
    
    private var placeholderPoster: some View {
        Rectangle()
            .foregroundStyle(.gray.opacity(0.2))
            .overlay {
                VStack {
                    Image(systemName: "film")
                        .font(.largeTitle)
                    Text("Kein Poster verfügbar")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
    }
    
    private func loadDetails() async {
        do {
            let fetched = try await TMDbAPI.shared.fetchMovieDetails(id: result.id)
            await MainActor.run {
                self.details = fetched
                self.isLoading = false
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.errorMessage = "TMDb API-Key fehlt. Bitte in TMDbAPI.swift eintragen."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Laden der Filmdetails."
                self.isLoading = false
            }
        }
    }
    
    private func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }
    
    // „Card“-Style Section (ohne Titel)
    private func section<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
    
    // Section mit Titel
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
    
    private func createMovie() -> Movie {
        if let d = details {
            let year = releaseYear(from: d.release_date) ?? "n/a"

            let genreNames = d.genres?.map { $0.name }
            let genreIds = d.genres?.map { $0.id }

            let keywordNames = d.keywords?.allKeywords.map { $0.name }
            let keywordIds = d.keywords?.allKeywords.map { $0.id }

            // ✅ NEU: Cast als [CastMember] statt [String]
            let castMembers: [CastMember]? = d.credits?.cast
                .prefix(30)
                .map {
                    CastMember(
                        personId: $0.id,
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.name.isEmpty }

            // ✅ NEU: Directors persistieren (für Director-Goals)
            let directorMembers: [CastMember]? = d.credits?.crew
                .filter { ($0.job ?? "").lowercased() == "director" }
                .map {
                    CastMember(
                        personId: $0.id,
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.name.isEmpty }

            return Movie(
                title: d.title,
                year: year,
                tmdbRating: d.vote_average,
                ratings: [],
                posterPath: d.poster_path,
                watchedDate: nil,
                watchedLocation: nil,
                tmdbId: d.id,
                genres: genreNames,
                genreIds: genreIds,
                keywords: keywordNames,
                keywordIds: keywordIds,
                suggestedBy: nil,
                cast: (castMembers?.isEmpty == true) ? nil : castMembers,
                directors: (directorMembers?.isEmpty == true) ? nil : directorMembers
            )
        } else {
            let year = releaseYear(from: result.release_date) ?? "n/a"
            return Movie(
                title: result.title,
                year: year,
                tmdbRating: result.vote_average,
                ratings: [],
                posterPath: result.poster_path,
                watchedDate: nil,
                watchedLocation: nil,
                tmdbId: result.id,
                genres: nil,
                genreIds: nil,
                keywords: nil,
                keywordIds: nil,
                suggestedBy: nil,
                cast: nil,
                directors: nil
            )
        }
    }
}

#Preview {
    SearchResultDetailView(
        result: TMDbMovieResult(
            id: 1,
            title: "Beispiel-Film",
            release_date: "2020-01-01",
            vote_average: 7.5,
            poster_path: nil
        ),
        isInitiallyInWatched: false,
        isInitiallyInBacklog: false,
        onAddToWatched: { _ in },
        onAddToBacklog: { _ in }
    )
}
