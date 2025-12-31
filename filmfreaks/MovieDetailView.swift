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

    // ✅ Quick Win: Overview expand
    @State private var isOverviewExpanded = false

    // ✅ Quick Win: Cast klickbar
    @State private var selectedPerson: SelectedPerson?

    // ✅ Quick Win: Save-UX (nicht bei jedem Tap speichern)
    @State private var hasPendingRatingChanges = false

    // ✅ Trailer Fallback: In-App (SFSafariViewController)
    @State private var isTrailerSafariShown = false

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

    // ✅ Trailer: wir arbeiten mit Key (für watch-url)
    private var trailerVideo: TMDbVideo? {
        guard let videos = details?.videos?.results else { return nil }
        let youtube = videos.filter { $0.site.lowercased() == "youtube" }

        // erst Trailer, dann Teaser als Fallback
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
        // Nur anzeigen, wenn er sich sinnvoll unterscheidet
        if o.caseInsensitiveCompare(details?.title ?? "") == .orderedSame { return nil }
        if o.caseInsensitiveCompare(movie.title) == .orderedSame { return nil }
        return o
    }

    private var originalLanguageText: String? {
        let code = (details?.original_language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }
        // Deutsche Anzeige, falls möglich
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

                    // ✅ Quick Win: Hero-Header (blurred Poster Background)
                    heroHeader

                    // Titel & Basisinfos
                    section {
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

                            // ✅ Release + Originaltitel/Sprache (Quick Win #2)
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

                    // ✅ Quick Win #1: Handlung/Overview (mit „Mehr anzeigen“)
                    if let overviewText {
                        section(title: "Handlung") {
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
                        || !castList.isEmpty
                        || keywordsText != nil
                        || trailerKey != nil
                        || !genreNames.isEmpty {

                        section(title: "Infos zum Film") {
                            VStack(alignment: .leading, spacing: 10) {

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

                                // ✅ Quick Win #4: Cast klickbar (✅ Sheet im Style der StatsView)
                                if !castList.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Hauptdarsteller")
                                            .font(.subheadline).bold()

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(castList, id: \.id) { person in
                                                    Button {
                                                        selectedPerson = SelectedPerson(
                                                            id: person.id,
                                                            name: person.name,
                                                            subtitle: person.character
                                                        )
                                                    } label: {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(person.name)
                                                                .font(.caption.weight(.semibold))
                                                                .foregroundStyle(.primary)
                                                                .lineLimit(1)

                                                            if let role = person.character?.trimmingCharacters(in: .whitespacesAndNewlines),
                                                               !role.isEmpty {
                                                                Text(role)
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.secondary)
                                                                    .lineLimit(1)
                                                            }
                                                        }
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 8)
                                                        .background(Color.blue.opacity(0.12))
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
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

                                // ✅ Trailer: Inline-Embed deaktiviert (zu oft „Video nicht verfügbar“ in WKWebView).
                                if let key = trailerKey {
                                    trailerInlineBlock(videoId: key)
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
                                        .onChange(of: localComment) { _, _ in
                                            hasPendingRatingChanges = true
                                        }
                                }

                                if hasPendingRatingChanges {
                                    Text("Änderungen noch nicht gespeichert.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    saveRating()
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                        Text(hasPendingRatingChanges ? "Änderungen speichern" : "Bewertung speichern")
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

    // MARK: - Trailer Block (ohne Embed)

    @ViewBuilder
    private func trailerInlineBlock(videoId: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trailer")
                .font(.subheadline).bold()

            if trailerWatchURL != nil {
                Button {
                    isTrailerSafariShown = true
                } label: {
                    ZStack {
                        // Preview: Poster (kein Backdrop vorhanden)
                        Group {
                            if let url = movie.posterURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle().foregroundStyle(.gray.opacity(0.15))
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        Rectangle().foregroundStyle(.gray.opacity(0.15))
                                    @unknown default:
                                        Rectangle().foregroundStyle(.gray.opacity(0.15))
                                    }
                                }
                            } else {
                                Rectangle().foregroundStyle(.gray.opacity(0.15))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.25),
                                    Color.black.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Play-Overlay
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 42, weight: .semibold))
                            Text("Trailer abspielen")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button {
                        isTrailerSafariShown = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "safari.fill")
                            Text("In App öffnen")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    if let trailerWatchURL {
                        Link(destination: trailerWatchURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                Text("In YouTube öffnen")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                Text("Hinweis: Der YouTube-Inline-Player ist deaktiviert, weil YouTube in WKWebView häufig mit „Video nicht verfügbar“ / Consent-Problemen reagiert. Über „In App öffnen“ ist es für Nutzer deutlich stabiler.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

            } else {
                Text("Trailer nicht verfügbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // ✅ Datenschutzhinweis (unaufdringlich, aber klar)
            VStack(alignment: .leading, spacing: 6) {
                Text("Datenschutz")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("Beim Abspielen wird ein YouTube-Video geöffnet. Dabei kann eine Verbindung zu YouTube/Google hergestellt und personenbezogene Daten (z. B. IP-Adresse) übertragen werden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://policies.google.com/privacy")!) {
                    Text("Google/YouTube Datenschutzerklärung öffnen")
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {

            // Background (blurred)
            Group {
                if let url = movie.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle().foregroundStyle(.gray.opacity(0.15))
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Rectangle().foregroundStyle(.gray.opacity(0.15))
                        @unknown default:
                            Rectangle().foregroundStyle(.gray.opacity(0.15))
                        }
                    }
                } else {
                    Rectangle().foregroundStyle(.gray.opacity(0.15))
                }
            }
            .frame(height: 320)
            .clipped()
            .blur(radius: 18)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            // Foreground Poster Card
            HStack(alignment: .bottom, spacing: 14) {
                Group {
                    if let url = movie.posterURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14).foregroundStyle(.gray.opacity(0.25))
                                    ProgressView()
                                }
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                placeholderPoster
                            @unknown default:
                                placeholderPoster
                            }
                        }
                    } else {
                        placeholderPoster
                    }
                }
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    if let tmdb = movie.tmdbRating {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                            Text(String(format: "%.1f / 10", tmdb))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)

                Spacer()
            }
            .padding(16)
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
                    hasPendingRatingChanges = true
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
                        hasPendingRatingChanges = true
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
                    hasPendingRatingChanges = true
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
                            hasPendingRatingChanges = true
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

        // ✅ Änderungen sind jetzt explizit gespeichert
        hasPendingRatingChanges = false
    }

    private func loadExistingRatingForSelectedUser() {
        guard let selectedUser = userStore.selectedUser else {
            localScores = [:]
            localComment = ""
            localFazitScore = nil
            hasPendingRatingChanges = false
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

        // ✅ frisch geladen => nix pending
        hasPendingRatingChanges = false
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

// MARK: - Cast Sheet Helper

private struct SelectedPerson: Identifiable {
    let id: Int
    let name: String
    let subtitle: String?
}

// MARK: - Person Detail Sheet (Style angelehnt an StatsView)

private struct TMDbPersonDetailSheet: View {
    let personId: Int
    let fallbackName: String
    let roleOrCharacter: String?

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading: Bool = false
    @State private var errorText: String? = nil
    @State private var details: TMDbPersonDetails? = nil
    @State private var isBioExpanded: Bool = false

    private var biographyText: String? {
        let t = (details?.biography ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var roleText: String? {
        let t = (roleOrCharacter ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Lade Personendaten …")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)

                    } else if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.top, 40)

                    } else if let details {

                        // Bild (✅ Option A: nix abschneiden)
                        if let path = details.profile_path,
                           let url = URL(string: "https://image.tmdb.org/t/p/w500\(path)") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)

                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                        .background(Color.gray.opacity(0.08))

                                case .failure:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                        .overlay {
                                            Image(systemName: "person.crop.rectangle")
                                                .font(.largeTitle)
                                                .foregroundStyle(.secondary)
                                        }

                                @unknown default:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(details.name)
                                .font(.title2.bold())

                            if let roleText {
                                Text(roleText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let dept = details.known_for_department,
                               !dept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(dept)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                if let birthday = details.birthday, !birthday.isEmpty {
                                    Label(birthday, systemImage: "gift.fill")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let place = details.place_of_birth, !place.isEmpty {
                                    Label(place, systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let popularity = details.popularity {
                                    Label(String(format: "Popularity %.1f", popularity),
                                          systemImage: "sparkles")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if let aliases = details.also_known_as, !aliases.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auch bekannt als")
                                    .font(.subheadline.weight(.semibold))
                                Text(aliases.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 6)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Biografie")
                                .font(.headline)

                            if let biographyText {
                                Text(biographyText)
                                    .font(.subheadline)
                                    .lineLimit(isBioExpanded ? nil : 10)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isBioExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(isBioExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                                        Image(systemName: isBioExpanded ? "chevron.up" : "chevron.down")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("Keine Biografie verfügbar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 6)

                    } else {
                        // „Fallback“ Zustand (sollte selten vorkommen)
                        Text("Keine Personendaten geladen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Darsteller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
            errorText = nil
            details = nil
        }

        do {
            let fetched = try await TMDbAPI.shared.fetchPersonDetails(id: personId)
            await MainActor.run {
                details = fetched
                isLoading = false
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                errorText = "TMDb API-Key fehlt."
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = "Fehler beim Laden der Personendaten."
                isLoading = false
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
