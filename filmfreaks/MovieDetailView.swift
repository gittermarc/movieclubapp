//
//  MovieDetailView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI
internal import UIKit

struct MovieDetailView: View {

    @Binding var movie: Movie
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    // Watch Providers Region (Land)
    @AppStorage(WatchProvidersRegionSettings.storageKey)
    private var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    var isBacklog: Bool

    @State private var localWatchedDate: Date = Date()
    @State private var localWatchedLocation: String = ""
    @State private var localScores: [RatingCriterion: Int] = [:]
    @State private var localSuggestedBy: String = ""
    @State private var localComment: String = ""
    @State private var localFazitScore: Int? = nil

    // TMDb Details
    @State private var details: TMDbMovieDetails?
    @State private var isLoadingDetails = false
    @State private var detailsError: String?

    // Streaming-Anbieter (Watch Providers)
    @State private var watchProvidersCountry: TMDbWatchProvidersCountry? = nil
    @State private var watchProvidersLink: URL? = nil
    @State private var isLoadingWatchProviders: Bool = false
    @State private var didLoadWatchProviders: Bool = false
    @State private var showWatchProvidersRegionPicker: Bool = false

    /// Effektives Land für Watch Providers (leer == automatisch/Device)
    private var effectiveWatchProvidersRegionCode: String {
        WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
        ?? WatchProvidersRegionSettings.deviceRegionCode()
    }

    private var isWatchProvidersRegionAutomatic: Bool {
        watchProvidersRegionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Aufklapp-Status der Einzelbewertungen
    @State private var expandedRatingIds: Set<UUID> = []

    // Overview expand
    @State private var isOverviewExpanded = false

    // Cast klickbar
    @State private var selectedPerson: SelectedPerson?

    // Save-UX
    @State private var hasPendingRatingChanges = false

    // Ratings Sheet
    @State private var showRatingsSheet = false

    // Trailer Fallback: In-App (SFSafariViewController)
    @State private var isTrailerSafariShown = false

    // Save-Toast
    @State private var showSaveToast = false
    @State private var saveToastText = "Bewertung gespeichert"
    @State private var toastDismissWorkItem: DispatchWorkItem?

    // MARK: - Metadaten aus TMDb

    private var director: String? {
        details?.credits?.crew.first(where: { ($0.job ?? "").lowercased() == "director" })?.name
    }

    private var castList: [TMDbCast] {
        Array(details?.credits?.cast.prefix(12) ?? [])
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

    private var trailerVideo: TMDbVideo? {
        guard let videos = details?.videos?.results else { return nil }
        let youtube = videos.filter { $0.site.lowercased() == "youtube" }

        if let trailer = youtube.first(where: { $0.type.lowercased() == "trailer" }) { return trailer }
        if let teaser = youtube.first(where: { $0.type.lowercased() == "teaser" }) { return teaser }
        return youtube.first
    }

    private var trailerKey: String? {
        trailerVideo?.key
    }

    private var trailerWatchURL: URL? {
        guard let key = trailerKey else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }

    private var runtimeText: String? {
        if let runtime = details?.runtime {
            return "\(runtime) Minuten"
        }
        return nil
    }

    private var taglineText: String? {
        let t = (details?.tagline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var overviewText: String? {
        let t = (details?.overview ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var releaseDateText: String? {
        guard let raw = details?.release_date, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let inFmt = DateFormatter()
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"

        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "de_DE")
        outFmt.dateFormat = "dd.MM.yyyy"

        if let date = inFmt.date(from: raw) {
            return outFmt.string(from: date)
        } else {
            return raw
        }
    }

    private var originalTitleText: String? {
        let o = (details?.original_title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !o.isEmpty else { return nil }
        if o.caseInsensitiveCompare(details?.title ?? "") == .orderedSame { return nil }
        if o.caseInsensitiveCompare(movie.title) == .orderedSame { return nil }
        return o
    }

    private var originalLanguageText: String? {
        let code = (details?.original_language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let locale = Locale(identifier: "de_DE")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
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

                    MovieDetailHeroHeaderView(movie: movie)

                    // Titel & Basisinfos
                    MovieDetailSectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.title)
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)

                            if let taglineText {
                                Text("„\(taglineText)“")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Jahr: \(movie.year)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let releaseDateText {
                                    Text("Release: \(releaseDateText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let originalTitleText {
                                    Text("Originaltitel: \(originalTitleText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                if let originalLanguageText {
                                    Text("Originalsprache: \(originalLanguageText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

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

                    // Watch Providers
                    if isLoadingWatchProviders {
                        MovieDetailSectionCard(title: "Film ist verfügbar bei:") {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Suche Streaming-Anbieter …")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if didLoadWatchProviders {
                        MovieDetailSectionCard(title: "Film ist verfügbar bei:") {
                            if let country = watchProvidersCountry,
                               !country.bestEffortProviders.isEmpty {
                                WatchProvidersAvailabilityView(country: country, link: watchProvidersLink)
                            } else {
                                WatchProvidersNoDataHintView(
                                    regionCode: effectiveWatchProvidersRegionCode,
                                    isAutomatic: isWatchProvidersRegionAutomatic
                                ) {
                                    showWatchProvidersRegionPicker = true
                                }
                            }
                        }
                    }

                    // Handlung
                    if let overviewText {
                        MovieDetailSectionCard(title: "Handlung") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(overviewText)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(isOverviewExpanded ? nil : 4)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isOverviewExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(isOverviewExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                                        Image(systemName: isOverviewExpanded ? "chevron.up" : "chevron.down")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Gesehen / Ort / Vorgeschlagen von
                    MovieDetailSectionCard(title: isBacklog ? "Backlog" : "Gesehen") {
                        MovieDetailWatchedSectionView(
                            isBacklog: isBacklog,
                            localWatchedDate: $localWatchedDate,
                            localWatchedLocation: $localWatchedLocation,
                            localSuggestedBy: $localSuggestedBy,
                            locationOptions: locationOptions,
                            suggestedByOptions: suggestedByOptions
                        ) {
                            markAsWatched()
                        }
                    }

                    // TMDb Loading/Error
                    if isLoadingDetails {
                        MovieDetailSectionCard {
                            HStack {
                                ProgressView()
                                Text("Lade zusätzliche Infos …")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if let error = detailsError {
                        MovieDetailSectionCard {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Infos
                    if runtimeText != nil
                        || director != nil
                        || !castList.isEmpty
                        || keywordsText != nil
                        || trailerKey != nil
                        || !genreNames.isEmpty {

                        MovieDetailSectionCard(title: "Infos zum Film") {
                            MovieDetailFilmInfoSectionView(
                                movie: movie,
                                runtimeText: runtimeText,
                                genreNames: genreNames,
                                director: director,
                                castList: castList,
                                keywordsText: keywordsText,
                                trailerKey: trailerKey,
                                trailerWatchURL: trailerWatchURL,
                                selectedPerson: $selectedPerson,
                                isTrailerSafariShown: $isTrailerSafariShown
                            )
                        }
                    }

                    // Bewertungen (Sheet)
                    Button {
                        showRatingsSheet = true
                    } label: {
                        MovieDetailSectionCard(title: "Bewertungen") {
                            VStack(alignment: .leading, spacing: 10) {

                                HStack(spacing: 8) {
                                    if let avg = movie.averageRating {
                                        Text(String(format: "Ø %.1f / 10", avg))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(displaySettings.tintSoftBackground)
                                            .clipShape(Capsule())
                                    } else {
                                        Text("Noch keine Bewertungen")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let f = movie.averageFazit {
                                        Text(String(format: "Fazit Ø %.1f", f))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.14))
                                            .clipShape(Capsule())
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 8) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.secondary)

                                    Text("\(movie.ratings.count) \(movie.ratings.count == 1 ? "Bewertung" : "Bewertungen")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Spacer(minLength: 0)

                                    if let name = userStore.selectedUser?.name {
                                        Text("Als: \(name)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                if hasPendingRatingChanges {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.orange)
                                        Text("Ungespeicherte Änderungen")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if !sortedRatings.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(sortedRatings.prefix(2)) { r in
                                            HStack(spacing: 10) {
                                                Text(r.reviewerName)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(1)

                                                Spacer(minLength: 0)

                                                Text(String(format: "%.1f / 10", r.averageScoreNormalizedTo10))
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.gray.opacity(0.10))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                } else {
                                    Text("Tippe hier, um eine Bewertung abzugeben.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding()
            }
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                if showSaveToast {
                    saveToastView
                        .padding(.bottom, max(12, proxy.safeAreaInsets.bottom + 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .allowsHitTesting(false)
        }
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPerson) { person in
            TMDbPersonDetailSheet(
                personId: person.id,
                fallbackName: person.name,
                roleOrCharacter: person.subtitle
            )
        }
        .sheet(isPresented: $isTrailerSafariShown) {
            if let url = trailerWatchURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                    Text("Trailer nicht verfügbar.")
                        .font(.headline)
                    Button("Schließen") { isTrailerSafariShown = false }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showWatchProvidersRegionPicker) {
            NavigationStack {
                WatchProvidersRegionPickerView()
            }
        }
        .sheet(isPresented: $showRatingsSheet) {
            MovieRatingsSheetView(
                movie: $movie,
                localScores: $localScores,
                localComment: $localComment,
                localFazitScore: $localFazitScore,
                expandedRatingIds: $expandedRatingIds,
                hasPendingRatingChanges: $hasPendingRatingChanges
            ) {
                saveRating()
            }
        }
        .onAppear { handleOnAppear() }
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
        .onChange(of: watchProvidersRegionCode) { _, _ in
            guard movie.tmdbId != nil else { return }
            Task { await reloadWatchProvidersOnly() }
        }
    }

    private func handleOnAppear() {
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

    // MARK: - Toast UI

    private var saveToastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
            Text(saveToastText)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
    }

    private func presentSaveToast(_ text: String = "Bewertung gespeichert") {
        saveToastText = text
        toastDismissWorkItem?.cancel()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSaveToast = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.25)) {
                showSaveToast = false
            }
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: workItem)
    }

    // MARK: - Haptics

    private func hapticSuccess() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    private func hapticWarning() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
    }

    // MARK: - Options

    private var locationOptions: [String] {
        var options: [String] = []

        func appendUnique(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !options.contains(trimmed) {
                options.append(trimmed)
            }
        }

        appendUnique("Heimkino")
        appendUnique("Kino")

        for name in userStore.users.map({ $0.name }) {
            appendUnique(name)
        }

        return options
    }

    private var suggestedByOptions: [String] {
        userStore.users.map { $0.name }
    }

    // MARK: - Rating Helpers

    private func normalizedScoresFromLocal() -> [RatingCriterion: Int] {
        var scores: [RatingCriterion: Int] = [:]
        for criterion in RatingCriterion.allCases {
            scores[criterion] = localScores[criterion] ?? 0
        }
        return scores
    }

    private func normalizedCommentFromLocal() -> String? {
        let trimmedComment = localComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedComment.isEmpty ? nil : trimmedComment
    }

    private func isAllDefault(scores: [RatingCriterion: Int], comment: String?, fazit: Int?) -> Bool {
        let allZero = RatingCriterion.allCases.allSatisfy { (scores[$0] ?? 0) == 0 }
        return allZero && comment == nil && fazit == nil
    }

    private func saveRating() {
        guard let selectedUser = userStore.selectedUser else { return }

        let scores = normalizedScoresFromLocal()
        let finalComment = normalizedCommentFromLocal()
        let fazit = localFazitScore
        let name = selectedUser.name

        let existingIndex = movie.ratings.firstIndex(where: { r in
            if let rid = r.reviewerId { return rid == selectedUser.id }
            return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        })
        let existingRating: Rating? = existingIndex.map { movie.ratings[$0] }

        if existingRating == nil, isAllDefault(scores: scores, comment: finalComment, fazit: fazit) {
            hasPendingRatingChanges = false
            hapticWarning()
            presentSaveToast("Keine Änderungen zum Speichern festgestellt")
            return
        }

        var newRating = Rating(
            reviewerId: selectedUser.id,
            reviewerName: name,
            scores: scores,
            comment: finalComment,
            fazitScore: fazit
        )

        if let index = existingIndex {
            let old = movie.ratings[index]
            newRating.id = old.id

            let oldComment = (old.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let newComment = (newRating.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let noScoreChanges = old.scores == newRating.scores
            let noCommentChanges = oldComment == newComment
            let noFazitChanges = old.fazitScore == newRating.fazitScore

            if noScoreChanges && noCommentChanges && noFazitChanges {
                hasPendingRatingChanges = false
                hapticWarning()
                presentSaveToast("Keine Änderungen zum Speichern festgestellt")
                return
            }
        }

        Task {
            let ok = await movieStore.upsertRating(for: movie.id, rating: newRating)

            hasPendingRatingChanges = false

            if ok {
                hapticSuccess()
                presentSaveToast("Bewertung gespeichert")
            } else {
                hapticWarning()
                presentSaveToast("Bewertung gespeichert – iCloud Sync fehlgeschlagen")
            }
        }
    }

    private func loadExistingRatingForSelectedUser() {
        guard let selectedUser = userStore.selectedUser else {
            localScores = [:]
            localComment = ""
            localFazitScore = nil
            hasPendingRatingChanges = false
            return
        }

        if let rating = movie.ratings.first(where: { r in
            if let rid = r.reviewerId { return rid == selectedUser.id }
            return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(selectedUser.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }) {
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

        hasPendingRatingChanges = false
    }

    // MARK: - Backlog

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

    // MARK: - TMDb Load

    private func loadDetails() async {
        guard let id = movie.tmdbId else { return }

        await MainActor.run {
            isLoadingDetails = true
            detailsError = nil

            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            async let detailsTask = TMDbAPI.shared.fetchMovieDetails(id: id)
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            async let providersTask = TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)

            let fetched = try await detailsTask
            let providersCountry = try? await providersTask

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

                // Cast als {personId, name} persistieren
                let castMembers = fetched.credits?.cast
                    .prefix(30)
                    .map {
                        CastMember(
                            personId: $0.id,
                            name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .filter { !$0.name.isEmpty }

                // Directors als {personId, name} persistieren (für Director-Goals)
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

                // Watch Providers
                self.watchProvidersCountry = providersCountry
                if let linkString = providersCountry?.link {
                    self.watchProvidersLink = URL(string: linkString)
                } else {
                    self.watchProvidersLink = nil
                }
                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true

                self.isLoadingDetails = false
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.detailsError = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoadingDetails = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch {
            await MainActor.run {
                self.detailsError = "Fehler beim Laden der Filmdetails."
                self.isLoadingDetails = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        }
    }

    private func reloadWatchProvidersOnly() async {
        guard let id = movie.tmdbId else { return }

        await MainActor.run {
            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            let providersCountry = try await TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)

            await MainActor.run {
                self.watchProvidersCountry = providersCountry
                if let linkString = providersCountry?.link {
                    self.watchProvidersLink = URL(string: linkString)
                } else {
                    self.watchProvidersLink = nil
                }

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch {
            await MainActor.run {
                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
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
