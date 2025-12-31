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
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

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
                    heroHeader

                    // Titel & Basisinfos (wie MovieDetailView)
                    section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(titleText)
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
                                if let yearText {
                                    Text("Jahr: \(yearText)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

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

                            let tmdb = details?.vote_average ?? result.vote_average
                            HStack(spacing: 6) {
                                Image(systemName: "star.circle")
                                Text(String(format: "TMDb: %.1f / 10", tmdb))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    // ✅ Handlung (wie MovieDetailView) – ohne „Beschreibung“-Card
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

                    // TMDb Infos / Loading / Error
                    if isLoading {
                        section {
                            HStack {
                                ProgressView()
                                Text("Lade zusätzliche Infos …")
                                    .font(.subheadline)
                            }
                        }
                    }

                    if let errorMessage {
                        section {
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

                                // ✅ Cast klickbar + Avatare + Fade (wie MovieDetailView)
                                if !castList.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Hauptdarsteller")
                                            .font(.subheadline).bold()

                                        ZStack(alignment: .trailing) {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(castList, id: \.id) { person in
                                                        Button {
                                                            selectedPerson = SRSelectedPerson(
                                                                id: person.id,
                                                                name: person.name,
                                                                subtitle: person.character
                                                            )
                                                        } label: {
                                                            HStack(alignment: .center, spacing: 8) {
                                                                castAvatar(profilePath: person.profile_path)

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

                                            if castList.count >= 9 {
                                                LinearGradient(
                                                    colors: [
                                                        Color(.secondarySystemBackground),
                                                        Color(.secondarySystemBackground).opacity(0.0)
                                                    ],
                                                    startPoint: .trailing,
                                                    endPoint: .leading
                                                )
                                                .frame(width: 28)
                                                .allowsHitTesting(false)
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

                                // ✅ Trailer: kein Embed, sondern Safari-Fallback (wie MovieDetailView)
                                if let key = trailerKey {
                                    trailerInlineBlock(videoId: key)
                                }
                            }
                        }
                    }

                    // ✅ Am Ende behalten: „Zu deiner Liste hinzufügen“
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
            Task { await loadDetails() }
        }
    }

    // MARK: - Trailer Block (ohne Embed, wie MovieDetailView)

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
                        Group {
                            if let url = posterURL {
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

    // MARK: - Hero Header (wie MovieDetailView)

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {

            Group {
                if let url = posterURL {
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

            HStack(alignment: .bottom, spacing: 14) {
                Group {
                    if let url = posterURL {
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
                    Text(titleText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let yearText {
                        Text(yearText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    let tmdb = details?.vote_average ?? result.vote_average
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                        Text(String(format: "%.1f / 10", tmdb))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 6)

                Spacer()
            }
            .padding(16)
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

    private func releaseYear(from dateString: String?) -> String? {
        guard let dateString, dateString.count >= 4 else { return nil }
        return String(dateString.prefix(4))
    }

    // „Card“-Style Section (ohne Titel)
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

    @ViewBuilder
    private func castAvatar(profilePath: String?) -> some View {
        let size: CGFloat = 34

        if let path = profilePath,
           let url = URL(string: "https://image.tmdb.org/t/p/w92\(path)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Circle().foregroundStyle(.gray.opacity(0.18))
                        ProgressView().scaleEffect(0.75)
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    ZStack {
                        Circle().foregroundStyle(.gray.opacity(0.18))
                        Image(systemName: "person.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                @unknown default:
                    ZStack {
                        Circle().foregroundStyle(.gray.opacity(0.18))
                        Image(systemName: "person.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        } else {
            ZStack {
                Circle().foregroundStyle(.gray.opacity(0.18))
                Image(systemName: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
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
                self.errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Laden der Filmdetails."
                self.isLoading = false
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

// MARK: - Cast Sheet Helper (eigene Namen, damit nix kollidiert)

private struct SRSelectedPerson: Identifiable {
    let id: Int
    let name: String
    let subtitle: String?
}

// MARK: - Person Detail Sheet (Style angelehnt an MovieDetailView/StatsView)

private struct SRTMDbPersonDetailSheet: View {
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

                        // Bild (Option A: nix abschneiden)
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
