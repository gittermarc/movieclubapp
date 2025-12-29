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
    @State private var localFazitScore: Int? = nil

    // TMDb-Details
    @State private var details: TMDbMovieDetails?
    @State private var isLoadingDetails = false
    @State private var detailsError: String?

    // ✅ NEU: Aufklapp-Status der Einzelbewertungen
    @State private var expandedRatingIds: Set<UUID> = []

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

    // MARK: - Bewertungen (Übersicht)

    private var sortedRatings: [Rating] {
        movie.ratings.sorted {
            $0.reviewerName.localizedCaseInsensitiveCompare($1.reviewerName) == .orderedAscending
        }
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

                    // Titel & Basisinfos
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

                    // ✅ Gesehen / Ort / Vorgeschlagen von (und Backlog-CTA)
                    section(title: isBacklog ? "Backlog" : "Gesehen") {
                        VStack(alignment: .leading, spacing: 12) {

                            if isBacklog {
                                Text("Dieser Film ist noch im Backlog.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    markAsWatched()
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Als gesehen markieren")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            } else {
                                DatePicker(
                                    "Gesehen am",
                                    selection: $localWatchedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                            }

                            // Ort
                            HStack {
                                Text("Ort")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()

                                Menu {
                                    Button {
                                        localWatchedLocation = ""
                                    } label: {
                                        Label("Ohne Angabe", systemImage: localWatchedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "checkmark" : "")
                                    }

                                    Divider()

                                    ForEach(locationOptions, id: \.self) { loc in
                                        Button {
                                            localWatchedLocation = loc
                                        } label: {
                                            Label(loc, systemImage: localWatchedLocation == loc ? "checkmark" : "")
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(localWatchedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Angabe" : localWatchedLocation)
                                            .font(.caption)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }

                            // Vorgeschlagen von
                            HStack {
                                Text("Vorgeschlagen von")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()

                                Menu {
                                    Button {
                                        localSuggestedBy = ""
                                    } label: {
                                        Label("Ohne Angabe", systemImage: localSuggestedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "checkmark" : "")
                                    }

                                    Divider()

                                    ForEach(suggestedByOptions, id: \.self) { name in
                                        Button {
                                            localSuggestedBy = name
                                        } label: {
                                            Label(name, systemImage: localSuggestedBy == name ? "checkmark" : "")
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(localSuggestedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Angabe" : localSuggestedBy)
                                            .font(.caption)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // TMDb Infos
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

                    // ✅ Rating Eingabe
                    section(title: "Bewertung") {
                        if userStore.selectedUser == nil {
                            Text("Bitte wähle oben in der App eine Person aus, um zu bewerten.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(RatingCriterion.allCases) { criterion in
                                    ratingRow(for: criterion)
                                }

                                fazitRow()

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Kommentar (optional)")
                                        .font(.subheadline.weight(.semibold))

                                    TextEditor(text: $localComment)
                                        .frame(minHeight: 80)
                                        .padding(8)
                                        .background(Color.gray.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                Button {
                                    saveRating()
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Bewertung speichern")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue.opacity(0.16))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // ✅ Kompakt: Einzelbewertungen (Ø/10 + Kommentar; Kriterien erst bei Tap)
                    section(title: "Einzelbewertungen") {
                        if sortedRatings.isEmpty {
                            Text("Noch keine Bewertungen vorhanden.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(sortedRatings) { rating in
                                    ratingSummaryCardCompact(rating)
                                }
                            }
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
            // Onboarding: zählt, wie oft die Detailansicht geöffnet wurde (pro Gruppe)
            OnboardingProgress.incrementDetailOpenCount(forGroupId: movie.groupId ?? movieStore.currentGroupId)

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
        .onChange(of: userStore.selectedUser?.id) { _, _ in
            loadExistingRatingForSelectedUser()
        }
    }

    // MARK: - Rating UI (Eingabe)

    @ViewBuilder
    private func ratingRow(for criterion: RatingCriterion) -> some View {
        let current = localScores[criterion] ?? 0

        VStack(alignment: .leading, spacing: 6) {
            Text(criterion.rawValue)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    localScores[criterion] = 0
                    saveRating()
                } label: {
                    Text("–")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(current == 0 ? Color.primary : Color.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(criterion.rawValue) nicht bewertet")

                ForEach(1...3, id: \.self) { value in
                    Button {
                        localScores[criterion] = value
                        saveRating()
                    } label: {
                        Image(systemName: value <= current ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(value <= current ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(criterion.rawValue) \(value) von 3")
                }

                Spacer()

                Text(current == 0 ? "– / 3" : "\(current) / 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fazit UI (1–10, separat)

    @ViewBuilder
    private func fazitRow() -> some View {
        let current = localFazitScore

        VStack(alignment: .leading, spacing: 6) {
            Text("Fazit (optional)")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Button {
                    localFazitScore = nil
                    saveRating()
                } label: {
                    Text("–")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(current == nil ? Color.primary : Color.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fazit nicht vergeben")

                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { value in
                        Button {
                            localFazitScore = value
                            saveRating()
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(colorForFazit(value).opacity(fazitOpacity(for: value, current: current)))
                                .frame(width: 18, height: 18)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fazit \(value) von 10")
                    }
                }

                Spacer()

                Text(current == nil ? "– / 10" : "\(current!) / 10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fazitOpacity(for value: Int, current: Int?) -> Double {
        guard let current else { return 0.22 }
        return value <= current ? 1.0 : 0.12
    }

    private func colorForFazit(_ value: Int) -> Color {
        // Linear von Rot (1) nach Grün (10)
        let clamped = min(10, max(1, value))
        let t = Double(clamped - 1) / 9.0
        let r = 1.0 - t
        let g = 0.15 + (0.85 * t)
        return Color(red: r, green: g, blue: 0.0)
    }

    // MARK: - Einzelbewertungen (kompakt + aufklappbar)

    private func isExpandedBinding(for rating: Rating) -> Binding<Bool> {
        Binding(
            get: { expandedRatingIds.contains(rating.id) },
            set: { newValue in
                if newValue {
                    expandedRatingIds.insert(rating.id)
                } else {
                    expandedRatingIds.remove(rating.id)
                }
            }
        )
    }

    @ViewBuilder
    private func ratingSummaryCardCompact(_ rating: Rating) -> some View {
        let comment = (rating.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasComment = !comment.isEmpty

        DisclosureGroup(isExpanded: isExpandedBinding(for: rating)) {
            // Inhalt: Kriterien + voller Kommentar (nur wenn expanded)
            VStack(alignment: .leading, spacing: 10) {

                VStack(alignment: .leading, spacing: 6) {

                    // Fazit (separat, 1–10)
                    HStack(spacing: 8) {
                        Text("Fazit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)

                        if let f = rating.fazitScore {
                            Text("Fazit \(f) / 10")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colorForFazit(f).opacity(0.18))
                                .clipShape(Capsule())
                        } else {
                            Text("Fazit –")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    ForEach(RatingCriterion.allCases) { criterion in
                        let score = rating.scores[criterion] ?? 0
                        HStack(spacing: 8) {
                            Text(criterion.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 90, alignment: .leading)

                            starsView(score: score)

                            Spacer()

                            Text(score == 0 ? "–" : "\(score)/3")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if hasComment {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(rating.reviewerName)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    HStack(spacing: 8) {
                        Text(String(format: "%.1f / 10", rating.averageScoreNormalizedTo10))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())

                        if let f = rating.fazitScore {
                            Text("Fazit \(f)/10")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(colorForFazit(f).opacity(0.18))
                                .clipShape(Capsule())
                        } else {
                            Text("Fazit –")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                }

                if hasComment {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func starsView(score: Int) -> some View {
        HStack(spacing: 6) {
            Text("–")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .opacity(score == 0 ? 1 : 0)
                .frame(width: 10, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(1...3, id: \.self) { idx in
                    Image(systemName: idx <= score ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(idx <= score ? Color.yellow : Color.secondary)
                }
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
        newRating.fazitScore = localFazitScore

        if let index = movie.ratings.firstIndex(where: { $0.reviewerName.lowercased() == name.lowercased() }) {
            // ✅ ID stabil halten, damit DisclosureGroup-States nicht „flackern“
            newRating.id = movie.ratings[index].id
            movie.ratings[index] = newRating
        } else {
            movie.ratings.append(newRating)
        }
    }

    private func loadExistingRatingForSelectedUser() {
        guard let selectedUser = userStore.selectedUser else {
            localScores = [:]
            localComment = ""
            localFazitScore = nil
            return
        }

        if let rating = movie.ratings.first(where: { $0.reviewerName.lowercased() == selectedUser.name.lowercased() }) {
            var scores: [RatingCriterion: Int] = [:]
            for criterion in RatingCriterion.allCases {
                scores[criterion] = rating.scores[criterion] ?? 0
            }
            localScores = scores
            localComment = rating.comment ?? ""
            localFazitScore = rating.fazitScore
        } else {
            var scores: [RatingCriterion: Int] = [:]
            for criterion in RatingCriterion.allCases {
                scores[criterion] = 0
            }
            localScores = scores
            localComment = ""
            localFazitScore = nil
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

                let genreIds = fetched.genres?.map { $0.id }

                let keywordNames = fetched.keywords?.allKeywords
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let keywordIds = fetched.keywords?.allKeywords.map { $0.id }

                // ✅ Cast als {personId, name} persistieren
                let castMembers = fetched.credits?.cast
                    .prefix(30)
                    .map {
                        CastMember(
                            personId: $0.id,
                            name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .filter { !$0.name.isEmpty }

                // ✅ Directors als {personId, name} persistieren (für Director-Goals)
                let directorMembers = fetched.credits?.crew
                    .filter { ($0.job ?? "").lowercased() == "director" }
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

                if let genreIds, !genreIds.isEmpty {
                    self.movie.genreIds = genreIds
                }

                if let keywordNames, !keywordNames.isEmpty {
                    self.movie.keywords = keywordNames
                }

                if let keywordIds, !keywordIds.isEmpty {
                    self.movie.keywordIds = keywordIds
                }

                if let castMembers, !castMembers.isEmpty {
                    self.movie.cast = castMembers
                }

                if let directorMembers, !directorMembers.isEmpty {
                    self.movie.directors = directorMembers
                }
                self.movie.tmdbRating = fetched.vote_average
                if let posterPath = fetched.poster_path {
                    self.movie.posterPath = posterPath
                }

                self.isLoadingDetails = false
            }

        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.detailsError = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
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
