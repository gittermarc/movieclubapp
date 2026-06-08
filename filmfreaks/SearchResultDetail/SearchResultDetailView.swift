//
//  SearchResultDetailView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

@MainActor
struct SearchResultDetailView: View {

    let result: TMDbMovieResult
    var onAddToWatched: (Movie) -> Void
    var onAddToBacklog: (Movie) -> Void

    // Neue Zustände: Ist der Film schon in einer Liste?
    @State var isInWatched: Bool
    @State var isInBacklog: Bool

    @Environment(\.dismiss) private var dismiss

    // ✅ NEU: User-Setting für Watch Providers Region (Land)
    @AppStorage(WatchProvidersRegionSettings.storageKey)
    var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    @StateObject var loadCoordinator = MovieMetadataLoadCoordinator()

    @State var showWatchProvidersRegionPicker: Bool = false

    // ✅ UI-States (wie MovieDetailView)
    @State var isOverviewExpanded: Bool = false
    @State var selectedPerson: SRSelectedPerson?

    // ✅ Trailer Fallback: In-App (SFSafariViewController)
    @State var isTrailerSafariShown = false

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
                        posterPath: details?.poster_path ?? result.poster_path,
                        posterURL: posterURL,
                        title: titleText,
                        yearText: yearText,
                        tmdbRating: details?.vote_average ?? result.vote_average,
                        backdropURL: heroBackdropURL,
                        runtimeText: runtimeText,
                        certificationText: certificationText
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

                    if let factsPresentation {
                        SearchResultDetailSectionCard(title: "Fakten") {
                            MovieFactsGridView(presentation: factsPresentation)
                        }
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
                        || !keywordNames.isEmpty
                        || trailerKey != nil
                        || !genreNames.isEmpty {

                        SearchResultDetailFilmInfoSectionView(
                            runtimeText: runtimeText,
                            genreNames: genreNames,
                            director: director,
                            castList: castList,
                            keywordNames: keywordNames,
                            shouldShowTrailer: trailerKey != nil,
                            trailerPreviewURL: trailerPreviewURL,
                            trailerWatchURL: trailerWatchURL,
                            isTrailerSafariShown: $isTrailerSafariShown
                        ) { personId, name, role in
                            selectPerson(personId: personId, name: name, role: role)
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
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
            if loadCoordinator.details == nil {
                Task { await loadDetails() }
            }
        }
        .onChange(of: result.id) { _, _ in
            isOverviewExpanded = false
            Task { await loadDetails() }
        }
        .onChange(of: watchProvidersRegionCode) { _, _ in
            Task { await reloadWatchProvidersOnly() }
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
