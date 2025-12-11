//
//  MovieDetailView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct MovieDetailView: View {
    
    @Binding var movie: Movie
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var movieStore: MovieStore
    @Environment(\.dismiss) private var dismiss
    
    var isBacklog: Bool
    
    @State private var localWatchedDate: Date = Date()
    @State private var localWatchedLocation: String = ""
    @State private var localScores: [RatingCriterion: Int] = [:]
    @State private var localSuggestedBy: String = ""
    @State private var localComment: String = ""   // Kommentar für aktuelle Bewertung
    
    // TMDb-Details
    @State private var details: TMDbMovieDetails?
    @State private var isLoadingDetails = false
    @State private var detailsError: String?
    
    // MARK: - Metadaten aus TMDb
    
    private var director: String? {
        details?.credits?.crew.first(where: { ($0.job ?? "").lowercased() == "director" })?.name
    }
    
    private var mainCast: String? {
        guard let cast = details?.credits?.cast, !cast.isEmpty else { return nil }
        let names = cast.prefix(6).map { $0.name }   // etwas begrenzen
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
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Gleicher Look wie SearchResultDetailView
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Poster
                    if let url = movie.posterURL {
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
                    
                    // Titel & Basisinfos als Card
                    section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(movie.title)
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("Jahr: \(movie.year)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if let tmdb = movie.tmdbRating {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.circle")
                                    Text(String(format: "TMDb: %.1f / 10", tmdb))
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // TMDb-Infos / Metadaten
                    if isLoadingDetails {
                        section {
                            HStack {
                                ProgressView()
                                Text("Lade zusätzliche Infos …")
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    if let error = detailsError {
                        section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    if runtimeText != nil
                        || director != nil
                        || mainCast != nil
                        || keywordsText != nil
                        || trailerURL != nil
                        || !genreNames.isEmpty {
                        
                        section(title: "Infos zum Film") {
                            VStack(alignment: .leading, spacing: 8) {
                                
                                if let runtimeText {
                                    Text("Laufzeit: \(runtimeText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
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
                    
                    // Nur „Gesehen“-Liste: Datum/Ort + Bewertungen
                    if !isBacklog {
                        
                        // Wann & wo geschaut + vorgeschlagen von
                        section(title: "Wann & wo geschaut") {
                            VStack(alignment: .leading, spacing: 8) {
                                DatePicker(
                                    "Gemeinsam geschaut am",
                                    selection: $localWatchedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                
                                Text("Wo haben wir geschaut?")
                                    .font(.subheadline)
                                
                                HStack {
                                    Menu {
                                        Button("Keine Angabe") {
                                            localWatchedLocation = ""
                                        }
                                        let options = locationOptions
                                        ForEach(options, id: \.self) { option in
                                            Button(option) {
                                                localWatchedLocation = option
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(localWatchedLocation.isEmpty ? "Ort wählen" : localWatchedLocation)
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text("Vorgeschlagen von:")
                                    .font(.subheadline)
                                    .padding(.top, 4)
                                
                                HStack {
                                    Menu {
                                        Button("Keine Angabe") {
                                            localSuggestedBy = ""
                                        }
                                        
                                        let options = suggestedByOptions
                                        if options.isEmpty {
                                            Text("Keine Mitglieder")
                                        } else {
                                            ForEach(options, id: \.self) { name in
                                                Button(name) {
                                                    localSuggestedBy = name
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(localSuggestedBy.isEmpty ? "Person wählen" : localSuggestedBy)
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        // Durchschnitt
                        if let avg = movie.averageRating {
                            section(title: "Durchschnitt unserer Bewertungen") {
                                Text(String(format: "%.1f / 10", avg))
                                    .font(.largeTitle)
                                    .bold()
                            }
                        }
                        
                        // Einzelbewertungen
                        if !movie.ratings.isEmpty {
                            section(title: "Einzelbewertungen") {
                                ForEach(movie.ratings) { rating in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(rating.reviewerName)
                                                .font(.subheadline)
                                                .bold()
                                            Spacer()
                                            Text(String(format: "%.1f / 10", rating.averageScoreNormalizedTo10))
                                                .font(.subheadline)
                                        }
                                        
                                        ForEach(RatingCriterion.allCases) { criterion in
                                            let value = rating.scores[criterion] ?? 0
                                            
                                            HStack {
                                                Text(criterion.rawValue)
                                                    .font(.caption)
                                                Spacer()
                                                Text(value == 0 ? "–" : String(repeating: "★", count: value))
                                                    .font(.caption)
                                            }
                                        }
                                        
                                        // Kommentar anzeigen, wenn vorhanden
                                        if let comment = rating.comment,
                                           !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Divider()
                                                .padding(.vertical, 4)
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "quote.opening")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .padding(.top, 2)
                                                Text(comment)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        // Bewertung hinzufügen / bearbeiten
                        section(title: "Bewertung hinzufügen / bearbeiten") {
                            VStack(alignment: .leading, spacing: 12) {
                                // Wer bewertet?
                                HStack {
                                    Text("Wer bewertet?")
                                    
                                    Spacer()
                                    
                                    Menu {
                                        ForEach(userStore.users) { user in
                                            Button(user.name) {
                                                userStore.selectedUser = user
                                                loadExistingRatingForSelectedUser()
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if let selected = userStore.selectedUser {
                                                Text(selected.name)
                                                    .font(.subheadline)
                                            } else {
                                                Text("Person wählen")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .padding(8)
                                        .background(.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                
                                // Kriterien 0–3 Sterne
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(RatingCriterion.allCases) { criterion in
                                        HStack {
                                            Text(criterion.rawValue)
                                            
                                            Spacer()
                                            
                                            let binding = Binding<Int>(
                                                get: { localScores[criterion] ?? 0 },
                                                set: { localScores[criterion] = $0 }
                                            )
                                            
                                            Picker("", selection: binding) {
                                                Text("–").tag(0)
                                                Text("★").tag(1)
                                                Text("★★").tag(2)
                                                Text("★★★").tag(3)
                                            }
                                            .pickerStyle(.segmented)
                                            .frame(width: 200)
                                        }
                                    }
                                }
                                
                                // Kommentarfeld
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Kommentar (optional)")
                                        .font(.subheadline)
                                    
                                    TextEditor(text: $localComment)
                                        .frame(minHeight: 60, maxHeight: 120)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                Button {
                                    saveRating()
                                } label: {
                                    Text("Speichern")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(userStore.selectedUser == nil)
                            }
                        }
                    }
                    
                    // Nur Backlog: „Vorgeschlagen von“ bearbeiten + „Als gesehen markieren“
                    if isBacklog {
                        
                        section(title: "Vorgeschlagen von") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wer hat diesen Film vorgeschlagen?")
                                    .font(.subheadline)
                                
                                HStack {
                                    Menu {
                                        Button("Keine Angabe") {
                                            localSuggestedBy = ""
                                        }
                                        
                                        let options = suggestedByOptions
                                        if options.isEmpty {
                                            Text("Keine Mitglieder")
                                        } else {
                                            ForEach(options, id: \.self) { name in
                                                Button(name) {
                                                    localSuggestedBy = name
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(localSuggestedBy.isEmpty ? "Person wählen" : localSuggestedBy)
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .padding(8)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        section(title: "Status") {
                            Button {
                                markAsWatched()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Als gesehen markieren")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Datum initial
            if let existing = movie.watchedDate {
                localWatchedDate = existing
            } else {
                localWatchedDate = Date()
                if !isBacklog {
                    movie.watchedDate = localWatchedDate
                }
            }
            
            // Ort initial
            localWatchedLocation = movie.watchedLocation ?? ""
            
            // Vorschlag initial
            localSuggestedBy = movie.suggestedBy ?? ""
            
            // Rating-Felder initialisieren
            loadExistingRatingForSelectedUser()
            
            // TMDb-Details nachladen, falls ID vorhanden
            if movie.tmdbId != nil {
                Task {
                    await loadDetails()
                }
            }
        }
        .onChange(of: localWatchedDate) { _, newDate in
            guard !isBacklog else { return }
            if movie.watchedDate != newDate {
                movie.watchedDate = newDate
            }
        }
        .onChange(of: localWatchedLocation) { _, newLocation in
            guard !isBacklog else { return }
            let trimmed = newLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            let newValue: String? = trimmed.isEmpty ? nil : trimmed
            if movie.watchedLocation != newValue {
                movie.watchedLocation = newValue
            }
        }
        .onChange(of: localSuggestedBy) { _, newSuggested in
            let trimmed = newSuggested.trimmingCharacters(in: .whitespacesAndNewlines)
            let newValue: String? = trimmed.isEmpty ? nil : trimmed
            if movie.suggestedBy != newValue {
                movie.suggestedBy = newValue
            }
        }
    }
    
    // MARK: - Helper Views / Funktionen
    
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
    
    private var locationOptions: [String] {
        var names = userStore.users.map { $0.name }
        if !names.contains("Kino") {
            names.append("Kino")
        }
        return names
    }
    
    private var suggestedByOptions: [String] {
        userStore.users.map { $0.name }
    }
    
    private func saveRating() {
        guard let selectedUser = userStore.selectedUser else { return }
        
        var scores: [RatingCriterion: Int] = [:]
        for criterion in RatingCriterion.allCases {
            scores[criterion] = localScores[criterion] ?? 0
        }
        
        let name = selectedUser.name
        let trimmedComment = localComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalComment: String? = trimmedComment.isEmpty ? nil : trimmedComment
        
        var newRating = Rating(
            reviewerName: name,
            scores: scores
        )
        newRating.comment = finalComment    // Kommentar anhängen
        
        if let index = movie.ratings.firstIndex(where: { $0.reviewerName.lowercased() == name.lowercased() }) {
            movie.ratings[index] = newRating
        } else {
            movie.ratings.append(newRating)
        }
    }
    
    private func loadExistingRatingForSelectedUser() {
        guard let selectedUser = userStore.selectedUser else {
            localScores = [:]
            localComment = ""
            return
        }
        
        if let rating = movie.ratings.first(where: { $0.reviewerName.lowercased() == selectedUser.name.lowercased() }) {
            var scores: [RatingCriterion: Int] = [:]
            for criterion in RatingCriterion.allCases {
                scores[criterion] = rating.scores[criterion] ?? 0
            }
            localScores = scores
            localComment = rating.comment ?? ""
        } else {
            var scores: [RatingCriterion: Int] = [:]
            for criterion in RatingCriterion.allCases {
                scores[criterion] = 0
            }
            localScores = scores
            localComment = ""
        }
    }
    
    private func markAsWatched() {
        // Backlog → Gesehen verschieben
        if let index = movieStore.backlogMovies.firstIndex(where: { $0.id == movie.id }) {
            var movedMovie = movieStore.backlogMovies.remove(at: index)
            if movedMovie.watchedDate == nil {
                movedMovie.watchedDate = Date()
            }
            if !movieStore.movies.contains(where: { $0.id == movedMovie.id }) {
                movieStore.movies.append(movedMovie)
            }
        }
        dismiss()
    }
    
    // Card-Section ohne Titel
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
    
    // Card-Section mit Titel
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
    
    private func loadDetails() async {
        guard let id = movie.tmdbId else { return }
        await MainActor.run {
            isLoadingDetails = true
            detailsError = nil
        }
        
        do {
            let fetched = try await TMDbAPI.shared.fetchMovieDetails(id: id)
            
            await MainActor.run {
                // Details für die View merken
                self.details = fetched
                
                // Movie mit Genres & Cast anreichern
                let genreNames = fetched.genres?
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                let castNames = fetched.credits?.cast
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if let genreNames, !genreNames.isEmpty {
                    self.movie.genres = genreNames
                }
                
                if let castNames, !castNames.isEmpty {
                    self.movie.cast = castNames
                }
                
                // Optional: TMDb-Rating & Poster aktualisieren, falls vorhanden
                self.movie.tmdbRating = fetched.vote_average
                if let posterPath = fetched.poster_path {
                    self.movie.posterPath = posterPath
                }
                
                self.isLoadingDetails = false
            }
            
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.detailsError = "TMDb API-Key fehlt. Bitte in TMDbAPI.swift eintragen."
                self.isLoadingDetails = false
            }
        } catch {
            await MainActor.run {
                self.detailsError = "Fehler beim Laden der Filmdetails."
                self.isLoadingDetails = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: .constant(
                Movie(
                    title: "Inception",
                    year: "2010",
                    tmdbRating: 8.8,
                    ratings: [],
                    posterPath: nil,
                    tmdbId: 27205
                )
            ),
            isBacklog: true
        )
        .environmentObject(UserStore())
        .environmentObject(MovieStore.preview())
    }
}
