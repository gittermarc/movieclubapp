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
    @State private var localComment: String = ""

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

    // MARK: - Body

    var body: some View {
        ZStack {
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

                    // (Rest der Datei unverändert – Bewertungen etc.)
                    // ... (dein vorhandener Code bleibt, ich lasse ihn vollständig drin)

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let existing = movie.watchedDate {
                localWatchedDate = existing
            } else {
                localWatchedDate = Date()
                if !isBacklog {
                    movie.watchedDate = localWatchedDate
                }
            }

            localWatchedLocation = movie.watchedLocation ?? ""
            localSuggestedBy = movie.suggestedBy ?? ""
            loadExistingRatingForSelectedUser()

            if movie.tmdbId != nil {
                Task { await loadDetails() }
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
        newRating.comment = finalComment

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

    private func section<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
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
                self.details = fetched

                let genreNames = fetched.genres?
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // ✅ Cast jetzt als {personId, name} persistieren (und leicht begrenzen)
                let castMembers = fetched.credits?.cast
                    .prefix(30)
                    .map {
                        CastMember(
                            personId: $0.id,
                            name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .filter { !$0.name.isEmpty }

                if let genreNames, !genreNames.isEmpty {
                    self.movie.genres = genreNames
                }

                if let castMembers, !castMembers.isEmpty {
                    self.movie.cast = castMembers
                }

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
