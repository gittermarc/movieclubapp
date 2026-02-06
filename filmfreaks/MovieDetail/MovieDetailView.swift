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
    var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    var isBacklog: Bool

    @State var localWatchedDate: Date = Date()
    @State var localWatchedLocation: String = ""
    @State var localScores: [RatingCriterion: Int] = [:]
    @State var localSuggestedBy: String = ""
    @State var localComment: String = ""
    @State var localFazitScore: Int? = nil

    // TMDb Details
    @State var details: TMDbMovieDetails?
    @State var isLoadingDetails = false
    @State var detailsError: String?

    // Streaming-Anbieter (Watch Providers)
    @State var watchProvidersCountry: TMDbWatchProvidersCountry? = nil
    @State var watchProvidersLink: URL? = nil
    @State var isLoadingWatchProviders: Bool = false
    @State var didLoadWatchProviders: Bool = false
    @State var showWatchProvidersRegionPicker: Bool = false

    /// Effektives Land für Watch Providers (leer == automatisch/Device)
    private var effectiveWatchProvidersRegionCode: String {
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
