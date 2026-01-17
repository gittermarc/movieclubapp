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

    // ✅ NEU: User-Setting für Watch Providers Region (Land)
    @AppStorage(WatchProvidersRegionSettings.storageKey)
    private var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    @State private var details: TMDbMovieDetails?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // ✅ NEU: Streaming-Anbieter (Watch Providers)
    @State private var watchProviders: [TMDbWatchProvider] = []
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

    // ✅ UI-States (wie MovieDetailView)
    @State private var isOverviewExpanded: Bool = false
    @State private var selectedPerson: SRSelectedPerson?

    // ✅ Trailer Fallback: In-App (SFSafariViewController)
    @State private var isTrailerSafariShown = false

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

    // MARK: - Metadaten aus TMDb (wie MovieDetailView)

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
        guard let raw = details?.release_date ?? result.release_date,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

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
        // Nur anzeigen, wenn er sich sinnvoll unterscheidet
        if o.caseInsensitiveCompare(details?.title ?? "") == .orderedSame { return nil }
        if o.caseInsensitiveCompare(result.title) == .orderedSame { return nil }
        return o
    }

    private var originalLanguageText: String? {
        let code = (details?.original_language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        let locale = Locale(identifier: "de_DE")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    private var titleText: String {
        details?.title ?? result.title
    }

    private var yearText: String? {
        releaseYear(from: details?.release_date ?? result.release_date)
    }

    // ✅ Trailer: wir arbeiten mit Key (für watch-url)
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

                    // ✅ Wie MovieDetailView: Hero-Header
                    SearchResultDetailHeroHeaderView(
                        posterURL: posterURL,
                        title: titleText,
                        yearText: yearText,
                        tmdbRating: details?.vote_average ?? result.vote_average
                    )

                    // Titel & Basisinfos (wie MovieDetailView)
                    SearchResultDetailTitleSectionView(
                        title: titleText,
                        taglineText: taglineText,
                        yearText: yearText,
                        releaseDateText: releaseDateText,
                        originalTitleText: originalTitleText,
                        originalLanguageText: originalLanguageText,
                        tmdbRating: details?.vote_average ?? result.vote_average
                    )

                    // ✅ NEU: Streaming-Anbieter vor Handlung
                    SearchResultDetailWatchProvidersSectionView(
                        isLoading: isLoadingWatchProviders,
                        didLoad: didLoadWatchProviders,
                        country: watchProvidersCountry,
                        link: watchProvidersLink,
                        effectiveRegionCode: effectiveWatchProvidersRegionCode,
                        isAutomatic: isWatchProvidersRegionAutomatic
                    ) {
                        showWatchProvidersRegionPicker = true
                    }

                    // ✅ Handlung (wie MovieDetailView) – ohne „Beschreibung“-Card
                    if let overviewText {
                        SearchResultDetailOverviewSectionView(
                            overviewText: overviewText,
                            isExpanded: $isOverviewExpanded
                        )
                    }

                    // TMDb Infos / Loading / Error
                    if isLoading {
                        SearchResultDetailSectionCard {
                            HStack {
                                ProgressView()
                                Text("Lade zusätzliche Infos …")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if let errorMessage {
                        SearchResultDetailSectionCard {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // ✅ Infos zum Film (wie MovieDetailView)
                    if runtimeText != nil
                        || director != nil
                        || !castList.isEmpty
                        || keywordsText != nil
                        || trailerKey != nil
                        || !genreNames.isEmpty {

                        SearchResultDetailFilmInfoSectionView(
                            runtimeText: runtimeText,
                            genreNames: genreNames,
                            director: director,
                            castList: castList,
                            keywordsText: keywordsText,
                            shouldShowTrailer: trailerKey != nil,
                            posterURL: posterURL,
                            trailerWatchURL: trailerWatchURL,
                            isTrailerSafariShown: $isTrailerSafariShown
                        ) { personId, name, role in
                            selectedPerson = SRSelectedPerson(id: personId, name: name, subtitle: role)
                        }
                    }

                    // ✅ Am Ende behalten: „Zu deiner Liste hinzufügen“
                    SearchResultDetailAddToListSectionView(
                        isInWatched: $isInWatched,
                        isInBacklog: $isInBacklog,
                        makeMovie: { createMovie() },
                        onAddToWatched: onAddToWatched,
                        onAddToBacklog: onAddToBacklog,
                        onDone: { dismiss() }
                    )

                    Spacer(minLength: 0)
                }
                .padding()
            }
        }
        .navigationTitle(result.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPerson) { person in
            SRTMDbPersonDetailSheet(
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
        .onAppear {
            if details == nil {
                isLoading = true
                errorMessage = nil
                Task { await loadDetails() }
            }
        }
        .onChange(of: result.id) { _, _ in
            isLoading = true
            errorMessage = nil
            details = nil
            isOverviewExpanded = false

            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProviders = []
            watchProvidersCountry = nil
            watchProvidersLink = nil
            Task { await loadDetails() }
        }
        .onChange(of: watchProvidersRegionCode) { _, _ in
            Task { await reloadWatchProvidersOnly() }
        }
    }

    private func reloadWatchProvidersOnly() async {
        await MainActor.run {
            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProviders = []
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            let providersCountry = try await TMDbAPI.shared.fetchMovieWatchProviders(id: result.id, region: region)

            await MainActor.run {
                self.watchProvidersCountry = providersCountry
                self.watchProviders = providersCountry?.bestEffortProviders ?? []

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

    // MARK: - Helper

    private var posterURL: URL? {
        let path = details?.poster_path ?? result.poster_path
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    private func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }


    private func loadDetails() async {
        await MainActor.run {
            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProviders = []
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            async let detailsTask = TMDbAPI.shared.fetchMovieDetails(id: result.id)
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            async let providersTask = TMDbAPI.shared.fetchMovieWatchProviders(id: result.id, region: region)

            let fetched = try await detailsTask
            let providersCountry = try? await providersTask

            await MainActor.run {
                self.details = fetched
                self.isLoading = false

                self.watchProvidersCountry = providersCountry
                self.watchProviders = providersCountry?.bestEffortProviders ?? []
                if let linkString = providersCountry?.link {
                    self.watchProvidersLink = URL(string: linkString)
                } else {
                    self.watchProvidersLink = nil
                }
                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoading = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Laden der Filmdetails."
                self.isLoading = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        }
    }

    private func createMovie() -> Movie {
        if let d = details {
            let year = releaseYear(from: d.release_date) ?? "n/a"

            let genreNames = d.genres?.map { $0.name }
            let genreIds = d.genres?.map { $0.id }

            let keywordNames = d.keywords?.allKeywords.map { $0.name }
            let keywordIds = d.keywords?.allKeywords.map { $0.id }

            let castMembers: [CastMember]? = d.credits?.cast
                .prefix(30)
                .map {
                    CastMember(
                        personId: $0.id,
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.name.isEmpty }

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
