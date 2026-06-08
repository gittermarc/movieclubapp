//
//  MovieDetailView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI
internal import UIKit

@MainActor
struct MovieDetailView: View {

    @Binding var movie: Movie
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    // Watch Providers Region (Land)
    @AppStorage(WatchProvidersRegionSettings.storageKey)
    var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    var isBacklog: Bool

    @State var localWatchedDate: Date = Date()
    @State var localWatchedLocation: String = ""
    @State var localScores: [RatingCriterion: Int] = [:]
    @State var localSuggestedBy: String = ""
    @State var localComment: String = ""
    @State var localFazitScore: Int? = nil

    @StateObject var loadCoordinator = MovieDetailLoadCoordinator()

    // Streaming-Anbieter (Watch Providers)
    @State var showWatchProvidersRegionPicker: Bool = false

    /// Effektives Land für Watch Providers (leer == automatisch/Device)
    var effectiveWatchProvidersRegionCode: String {
        WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
        ?? WatchProvidersRegionSettings.deviceRegionCode()
    }

    private var isWatchProvidersRegionAutomatic: Bool {
        watchProvidersRegionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Aufklapp-Status der Einzelbewertungen
    @State var expandedRatingIds: Set<UUID> = []

    // Overview expand
    @State var isOverviewExpanded = false

    // Cast klickbar
    @State var selectedPerson: SelectedPerson?

    // Save-UX
    @State var hasPendingRatingChanges = false

    // Ratings Sheet
    @State var showRatingsSheet = false

    // Trailer Fallback: In-App (SFSafariViewController)
    @State var isTrailerSafariShown = false

    // Save-Toast
    @State var showSaveToast = false
    @State var saveToastText = "Bewertung gespeichert"
    @State var toastDismissWorkItem: DispatchWorkItem?

    // MARK: - Metadaten aus TMDb
    // (ausgelagert in MovieDetailView+Derived.swift)

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

                    MovieMetadataHeroHeaderView(
                        posterURL: heroPosterURL,
                        backdropURL: heroBackdropURL,
                        posterFallbackBackgroundURL: heroPosterFallbackBackgroundURL,
                        title: movie.title,
                        yearText: movie.year,
                        tmdbRating: movie.tmdbRating,
                        groupRating: movie.groupAverage(for: displaySettings.ratingDisplayMode),
                        runtimeText: runtimeText,
                        certificationText: certificationText
                    )

                    // Titel & Basisinfos
                    MovieDetailTitleSectionView(
                        title: movie.title,
                        year: movie.year,
                        taglineText: taglineText,
                        releaseDateText: nil,
                        originalTitleText: nil,
                        originalLanguageText: nil,
                        tmdbRating: movie.tmdbRating
                    )

                    // Watch Providers
                    MovieDetailWatchProvidersSectionView(
                        isLoading: loadCoordinator.isLoadingWatchProviders,
                        didLoad: loadCoordinator.didLoadWatchProviders,
                        country: loadCoordinator.watchProvidersCountry,
                        link: loadCoordinator.watchProvidersLink,
                        regionCode: effectiveWatchProvidersRegionCode,
                        isAutomatic: isWatchProvidersRegionAutomatic
                    ) {
                        showWatchProvidersRegionPicker = true
                    }

                    if let factsPresentation {
                        MovieDetailSectionCard(title: "Fakten") {
                            MovieFactsGridView(presentation: factsPresentation)
                        }
                    }

                    // Handlung
                    MovieDetailOverviewSectionView(
                        overviewText: overviewText,
                        isExpanded: $isOverviewExpanded
                    )

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
                    if loadCoordinator.isLoadingDetails {
                        MovieDetailSectionCard {
                            HStack {
                                ProgressView()
                                Text("Lade zusätzliche Infos …")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if let error = loadCoordinator.detailsError {
                        MovieDetailSectionCard {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // Infos
                    if director != nil
                        || !castList.isEmpty
                        || !keywordNames.isEmpty
                        || trailerKey != nil
                        || !genreNames.isEmpty {

                        MovieDetailSectionCard(title: "Infos zum Film") {
                            MovieDetailFilmInfoSectionView(
                                movie: movie,
                                runtimeText: nil,
                                genreNames: genreNames,
                                director: director,
                                castList: castList,
                                keywordNames: keywordNames,
                                trailerKey: trailerKey,
                                trailerPreviewURL: trailerPreviewURL,
                                trailerWatchURL: trailerWatchURL,
                                selectedPerson: $selectedPerson,
                                isTrailerSafariShown: $isTrailerSafariShown
                            )
                        }
                    }

                    // Bewertungen (Sheet)
                    MovieDetailRatingsTeaserCardView(
                        averageRating: movie.averageRating,
                        averageFazit: movie.averageFazit,
                        ratingsCount: movie.ratings.count,
                        selectedUserName: userStore.selectedUser?.name,
                        hasPendingChanges: hasPendingRatingChanges,
                        ratingsPreview: Array(sortedRatings.prefix(2)),
                        tintSoftBackground: displaySettings.tintSoftBackground
                    ) {
                        showRatingsSheet = true
                    }

                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                if showSaveToast {
                    MovieDetailSaveToastView(text: saveToastText)
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
            handleWatchedDateChange(newDate)
        }
        .onChange(of: localWatchedLocation) { _, newLocation in
            handleWatchedLocationChange(newLocation)
        }
        .onChange(of: localSuggestedBy) { _, newSuggested in
            handleSuggestedByChange(newSuggested)
        }
        .onChange(of: userStore.selectedUser?.id) { _, _ in
            handleSelectedUserChange()
        }
        .onChange(of: watchProvidersRegionCode) { _, _ in
            handleWatchProvidersRegionChange()
        }
    }

    // MARK: - Toast

    func presentSaveToast(_ text: String = "Bewertung gespeichert") {
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

    func hapticSuccess() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    func hapticWarning() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
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
    // (ausgelagert in MovieDetailView+TMDb.swift)
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
