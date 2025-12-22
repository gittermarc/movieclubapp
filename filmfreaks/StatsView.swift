//
//  StatsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 29.11.25.
//

internal import SwiftUI

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case last30 = "Letzte 30 Tage"
    case last90 = "Letzte 90 Tage"
    case thisYear = "Dieses Jahr"
    case all = "Gesamte Zeit"

    var id: Self { self }
}

enum StatsDrilldown: Identifiable {
    case month(Date)
    case location(String)
    case suggestedBy(String)

    var id: String {
        switch self {
        case .month(let date):
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            return "month_\(y)_\(m)"
        case .location(let loc):
            return "location_\(loc)"
        case .suggestedBy(let name):
            return "suggestedBy_\(name)"
        }
    }
}

private struct GenreDrilldown: Identifiable, Hashable {
    let genre: String
    var id: String { genre }
}

private struct ActorEntry: Identifiable, Hashable {
    let personId: Int
    let name: String
    let count: Int
    var id: Int { personId }
}

struct StatsView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore

    @State private var selectedRange: StatsTimeRange = .all
    @State private var selectedLocationFilter: String? = nil

    // ✅ Popularity Store (persistiert + TTL)
    @ObservedObject private var popularityStore = PersonPopularityStore.shared

    // Darsteller UI
    @State private var showAllActors: Bool = false
    @State private var actorDisplayOrder: [ActorEntry] = []
    @State private var actorSortGeneration: UUID = UUID()

    // Genres UI
    @State private var genreDisplayOrder: [(genre: String, count: Int)] = []
    @State private var genreSortGeneration: UUID = UUID()

    private let collapsedActorsCount: Int = 25
    private let expandedActorsCount: Int = 50

    // Drilldown
    @State private var selectedDrilldown: StatsDrilldown? = nil

    // Actor Sheet
    @State private var selectedActor: ActorEntry? = nil
    @State private var selectedActorDetails: TMDbPersonDetails? = nil
    @State private var isLoadingActor: Bool = false
    @State private var actorError: String? = nil
    @State private var showingActorSheet: Bool = false

    // Genre Sheet
    @State private var selectedGenreDrilldown: GenreDrilldown? = nil

    private static let recentDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                List {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {

                            if let groupName = movieStore.currentGroupName {
                                Text("Statistiken für „\(groupName)“")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Statistiken für deine aktuelle Gruppe")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Filter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("Zeitraum")
                                    .font(.subheadline)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(StatsTimeRange.allCases) { range in
                                            let isSelected = (range == selectedRange)

                                            Button { selectedRange = range } label: {
                                                Text(range.rawValue)
                                                    .font(.caption)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 999)
                                                            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 999)
                                                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                                                    )
                                                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                            }
                                        }
                                    }
                                }

                                HStack {
                                    Text("Ort").font(.subheadline)
                                    Spacer()

                                    Menu {
                                        Button {
                                            selectedLocationFilter = nil
                                        } label: {
                                            Label("Alle Orte", systemImage: selectedLocationFilter == nil ? "checkmark" : "")
                                        }

                                        Divider()

                                        ForEach(availableLocations, id: \.self) { loc in
                                            Button {
                                                selectedLocationFilter = loc
                                            } label: {
                                                Label(loc, systemImage: selectedLocationFilter == loc ? "checkmark" : "")
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(selectedLocationFilter ?? "Alle Orte")
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
                        .padding(.vertical, 4)
                    }

                    // Dashboard
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            statsCard(title: "Filme", subtitle: "im Zeitraum", value: "\(filteredMovies.count)", icon: "film")

                            statsCard(
                                title: "Ø Bewertung",
                                subtitle: "im Zeitraum",
                                value: overallAverageRating != nil ? String(format: "%.1f", overallAverageRating!) : "–",
                                icon: "star.fill"
                            )

                            statsCard(
                                title: "Zuletzt",
                                subtitle: "gesehen",
                                value: mostRecentWatchedDate != nil ? Self.recentDateFormatter.string(from: mostRecentWatchedDate!) : "–",
                                icon: "clock"
                            )

                            statsCard(title: "Orte", subtitle: "im Zeitraum", value: "\(moviesByLocation.count)", icon: "mappin.and.ellipse")
                        }
                        .padding(.vertical, 6)
                    }

                    // Filme pro Monat
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Filme pro Monat").font(.headline)
                                Spacer()
                                Image(systemName: "calendar").foregroundStyle(.secondary)
                            }

                            if moviesPerMonth.isEmpty {
                                Text("Keine Filme im ausgewählten Zeitraum.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(moviesPerMonth, id: \.date) { entry in
                                    HStack {
                                        Text(monthFormatter.string(from: entry.date))
                                        Spacer()
                                        Button {
                                            selectedDrilldown = .month(entry.date)
                                        } label: {
                                            Text("\(entry.count)")
                                                .font(.footnote)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Genres
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Genres").font(.headline)
                                Spacer()
                                Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary)
                            }

                            if genresDisplaySource.isEmpty {
                                Text("Keine Genres im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Eure häufigsten Genres")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(genresDisplaySource.prefix(30), id: \.genre) { entry in
                                        Button {
                                            genreChipTapped(entry.genre)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(entry.genre)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Text("(\(entry.count))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .transaction { $0.animation = nil }

                                Text("Tippe ein Genre, um die passenden Filme im Zeitraum zu sehen.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Darsteller (✅ personId-basiert)
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Darsteller").font(.headline)
                                Spacer()
                                Image(systemName: "person.2.fill").foregroundStyle(.secondary)
                            }

                            if actorsByCountRaw.isEmpty {
                                Text("Keine Cast-Daten im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Wen ihr am häufigsten seht")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                let actorSource = actorsDisplaySource
                                let limit = showAllActors ? expandedActorsCount : collapsedActorsCount
                                let displayedActors = Array(actorSource.prefix(limit))

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(displayedActors) { entry in
                                        Button {
                                            actorChipTapped(entry)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(entry.name)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Text("(\(entry.count))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .transaction { $0.animation = nil }

                                if actorSource.count > collapsedActorsCount {
                                    Button {
                                        showAllActors.toggle()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(showAllActors ? "Weniger anzeigen" : "Mehr anzeigen")
                                                .font(.footnote.weight(.semibold))
                                            Image(systemName: showAllActors ? "chevron.up" : "chevron.down")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Orte
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Orte").font(.headline)
                                Spacer()
                                Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                            }

                            if moviesByLocation.isEmpty {
                                Text("Keine Filme im ausgewählten Zeitraum.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(moviesByLocation, id: \.location) { entry in
                                    HStack {
                                        Text(entry.location)
                                        Spacer()
                                        Button { selectedDrilldown = .location(entry.location) } label: {
                                            Text("\(entry.count)")
                                                .font(.footnote)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Vorgeschlagen von
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Vorgeschlagen von").font(.headline)
                                Spacer()
                                Image(systemName: "person.fill.questionmark").foregroundStyle(.secondary)
                            }

                            if suggestionsByUser.isEmpty {
                                Text("Keine Vorschläge im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(suggestionsByUser, id: \.name) { entry in
                                    HStack {
                                        Text(entry.name)
                                        Spacer()
                                        Button { selectedDrilldown = .suggestedBy(entry.name) } label: {
                                            Text("\(entry.count)")
                                                .font(.footnote)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.orange.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Pro Person
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bewertungen pro Person").font(.headline)
                                Spacer()
                                Image(systemName: "person.3.sequence.fill").foregroundStyle(.secondary)
                            }

                            if userStore.users.isEmpty {
                                Text("Noch keine Mitglieder in der Filmgruppe.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(userStore.users) { user in
                                        let stats = statsForUser(user)

                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(user.name)
                                                    .font(.subheadline.weight(.semibold))
                                                Text("\(stats.movieCount) Filme bewertet")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if let avg = stats.averageRating {
                                                Text(String(format: "%.1f", avg))
                                                    .font(.headline)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.blue.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            } else {
                                                Text("–")
                                                    .font(.headline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Statistiken")
            }
        }
        .onAppear {
            setGenreDisplayOrderNow()
            triggerActorPopularityPreload()
        }
        .onChange(of: selectedRange) {
            setGenreDisplayOrderNow()
            triggerActorPopularityPreload()
        }
        .onChange(of: selectedLocationFilter) {
            setGenreDisplayOrderNow()
            triggerActorPopularityPreload()
        }
        .onChange(of: movieStore.movies.count) {
            triggerGenreDisplayRecomputeDebounced()
            triggerActorPopularityPreload()
        }
        .onChange(of: showAllActors) {
            preloadPopularityForVisibleActors()
        }
        .sheet(isPresented: $showingActorSheet) {
            actorDetailSheet()
        }
        .sheet(item: $selectedGenreDrilldown) { selection in
            genreMoviesSheet(for: selection.genre)
        }
        .sheet(item: $selectedDrilldown) { drilldown in
            drilldownMoviesSheet(drilldown)
        }
    }

    // MARK: - Dashboard Karte

    private func statsCard(title: String, subtitle: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            Text(value).font(.title2.bold())
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Basis & Filter

    private var moviesForCurrentTimeRange: [Movie] {
        let calendar = Calendar.current
        let today = Date()

        return movieStore.movies.compactMap { movie in
            guard let date = movie.watchedDate else { return nil }

            switch selectedRange {
            case .all:
                return movie
            case .thisYear:
                if calendar.isDate(date, equalTo: today, toGranularity: .year) { return movie }
            case .last30:
                if let from = calendar.date(byAdding: .day, value: -30, to: today),
                   date >= from { return movie }
            case .last90:
                if let from = calendar.date(byAdding: .day, value: -90, to: today),
                   date >= from { return movie }
            }
            return nil
        }
    }

    private var filteredMovies: [Movie] {
        guard let loc = selectedLocationFilter else {
            return moviesForCurrentTimeRange
        }
        return moviesForCurrentTimeRange.filter { normalizedLocation(for: $0) == loc }
    }

    private var availableLocations: [String] {
        let locations = moviesForCurrentTimeRange.map { normalizedLocation(for: $0) }
        let unique = Set(locations)
        return Array(unique).sorted()
    }

    private func normalizedLocation(for movie: Movie) -> String {
        let trimmed = movie.watchedLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Ohne Angabe" : trimmed
    }

    // MARK: - Aggregationen

    private var overallAverageRating: Double? {
        let allScores = filteredMovies.flatMap { movie in
            movie.ratings.map { $0.averageScoreNormalizedTo10 }
        }
        guard !allScores.isEmpty else { return nil }
        let total = allScores.reduce(0, +)
        return total / Double(allScores.count)
    }

    private var mostRecentWatchedDate: Date? {
        filteredMovies.compactMap { $0.watchedDate }.max()
    }

    private var moviesPerMonth: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]

        for movie in filteredMovies {
            guard let date = movie.watchedDate else { continue }
            if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
                counts[monthStart, default: 0] += 1
            }
        }

        return counts
            .map { (date: $0.key, count: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private var moviesByGenreRaw: [(genre: String, count: Int)] {
        var counts: [String: Int] = [:]

        for movie in filteredMovies {
            guard let genres = movie.genres else { continue }
            for g in genres {
                let name = g.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                counts[name, default: 0] += 1
            }
        }

        return counts
            .map { (genre: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.genre.localizedCaseInsensitiveCompare($1.genre) == .orderedAscending
            }
    }

    private var genresDisplaySource: [(genre: String, count: Int)] {
        genreDisplayOrder.isEmpty ? moviesByGenreRaw : genreDisplayOrder
    }

    /// ✅ Rohdaten: Häufigkeit pro Darsteller – personId-basiert
    private var actorsByCountRaw: [ActorEntry] {
        var counts: [Int: (name: String, count: Int)] = [:]

        for movie in filteredMovies {
            guard let cast = movie.cast else { continue }
            for member in cast {
                let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                if var existing = counts[member.personId] {
                    existing.count += 1
                    // Namen behalten wir stabil (erster gewinnt)
                    counts[member.personId] = existing
                } else {
                    counts[member.personId] = (name: trimmed, count: 1)
                }
            }
        }

        return counts
            .map { ActorEntry(personId: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var actorsDisplaySource: [ActorEntry] {
        actorDisplayOrder.isEmpty ? actorsByCountRaw : actorDisplayOrder
    }

    /// Sortierung: Häufigkeit, dann Popularität (per personId), dann Name
    private func computeActorsSortedUsingPopularity() -> [ActorEntry] {
        let raw = actorsByCountRaw
        return raw.sorted { a, b in
            if a.count != b.count { return a.count > b.count }

            let popA = popularityStore.popularityValue(for: a.personId)
            let popB = popularityStore.popularityValue(for: b.personId)
            if popA != popB { return popA > popB }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private var moviesByLocation: [(location: String, count: Int)] {
        var counts: [String: Int] = [:]

        for movie in filteredMovies {
            let loc = normalizedLocation(for: movie)
            counts[loc, default: 0] += 1
        }

        return counts
            .map { (location: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var suggestionsByUser: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]

        for movie in filteredMovies {
            guard let raw = movie.suggestedBy else { continue }
            let sugg = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sugg.isEmpty else { continue }
            counts[sugg, default: 0] += 1
        }

        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df
    }

    private func statsForUser(_ user: User) -> (movieCount: Int, averageRating: Double?) {
        var movieIds = Set<UUID>()
        var scores: [Double] = []

        for movie in filteredMovies {
            let userRatings = movie.ratings.filter { $0.reviewerName == user.name }
            if !userRatings.isEmpty {
                movieIds.insert(movie.id)
                scores.append(contentsOf: userRatings.map { $0.averageScoreNormalizedTo10 })
            }
        }

        guard !scores.isEmpty else { return (movieIds.count, nil) }

        let total = scores.reduce(0, +)
        let avg = total / Double(scores.count)
        return (movieIds.count, avg)
    }

    // MARK: - Actor Filme

    private var moviesForSelectedActor: [Movie] {
        guard let actor = selectedActor else { return [] }
        return filteredMovies.filter { movie in
            guard let cast = movie.cast else { return false }
            return cast.contains(where: { $0.personId == actor.personId })
        }
    }

    // MARK: - Genre UI Stabilisierung

    private func setGenreDisplayOrderNow() {
        let gen = UUID()
        genreSortGeneration = gen
        genreDisplayOrder = moviesByGenreRaw
    }

    private func triggerGenreDisplayRecomputeDebounced() {
        let gen = UUID()
        genreSortGeneration = gen

        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                guard genreSortGeneration == gen else { return }
                genreDisplayOrder = moviesByGenreRaw
            }
        }
    }

    // MARK: - Popularity Preload (✅ nur /person/{id}, TTL-Cache)

    private func triggerActorPopularityPreload() {
        let generation = UUID()
        actorSortGeneration = generation

        let base = actorsByCountRaw
        actorDisplayOrder = base

        Task {
            let visibleLimit = showAllActors ? expandedActorsCount : collapsedActorsCount
            let visibleIds = Array(base.prefix(visibleLimit)).map { $0.personId }
            await popularityStore.preloadPopularity(for: visibleIds)

            let allIds = base.map { $0.personId }
            await popularityStore.preloadPopularity(for: allIds)

            await MainActor.run {
                guard actorSortGeneration == generation else { return }
                actorDisplayOrder = computeActorsSortedUsingPopularity()
            }
        }
    }

    private func preloadPopularityForVisibleActors() {
        let base = actorsByCountRaw
        if base.isEmpty { return }

        let visibleLimit = showAllActors ? expandedActorsCount : collapsedActorsCount
        let visibleIds = Array(base.prefix(visibleLimit)).map { $0.personId }

        Task {
            await popularityStore.preloadPopularity(for: visibleIds)
        }
    }

    // MARK: - Actor Interaction

    private func actorChipTapped(_ actor: ActorEntry) {
        selectedActor = actor
        selectedActorDetails = nil
        actorError = nil
        isLoadingActor = true
        showingActorSheet = true

        // ✅ Actor-Sheet lädt Details per ID (keine Suche)
        Task {
            do {
                let details = try await TMDbAPI.shared.fetchPersonDetails(id: actor.personId)
                await MainActor.run {
                    self.selectedActorDetails = details
                    self.isLoadingActor = false
                }
            } catch {
                await MainActor.run {
                    self.actorError = "Fehler beim Laden der Personendaten."
                    self.isLoadingActor = false
                }
            }
        }
    }

    @ViewBuilder
    private func actorDetailSheet() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if isLoadingActor {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Lade Personendaten …")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)

                    } else if let error = actorError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.top, 40)

                    } else if let details = selectedActorDetails {

                        if let path = details.profile_path,
                           let url = URL(string: "https://image.tmdb.org/t/p/w300\(path)") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(height: 260)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 260)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(height: 260)
                                        .overlay {
                                            Image(systemName: "person.crop.rectangle")
                                                .font(.largeTitle)
                                                .foregroundStyle(.secondary)
                                        }
                                @unknown default:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(height: 260)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(details.name)
                                .font(.title2.bold())

                            if let dept = details.known_for_department, !dept.isEmpty {
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
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biografie").font(.headline)

                            if let bio = details.biography,
                               !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(bio).font(.body)
                            } else {
                                Text("Keine Biografie verfügbar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    } else {
                        Text("Keine Personendaten geladen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }

                    if let actor = selectedActor,
                       !moviesForSelectedActor.isEmpty {

                        Divider().padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("In eurer Gruppe gesehen")
                                .font(.headline)

                            Text("Filme im aktuell gewählten Zeitraum und Ort, in denen \(actor.name) mitspielt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(moviesForSelectedActor) { movie in
                                movieRow(movie)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Darsteller")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { showingActorSheet = false }
                }
            }
        }
    }

    // MARK: - Genre Interaction

    private func genreChipTapped(_ genre: String) {
        selectedGenreDrilldown = GenreDrilldown(genre: genre)
    }

    @ViewBuilder
    private func genreMoviesSheet(for genre: String) -> some View {
        NavigationStack {
            List {
                let movies = filteredMovies.filter { movie in
                    (movie.genres ?? []).contains(where: { $0.lowercased() == genre.lowercased() })
                }

                if movies.isEmpty {
                    Text("Keine Filme für „\(genre)“ im aktuellen Filter.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(genre)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedGenreDrilldown = nil }
                }
            }
        }
    }

    // MARK: - Drilldown Sheets

    @ViewBuilder
    private func drilldownMoviesSheet(_ drilldown: StatsDrilldown) -> some View {
        switch drilldown {
        case .month(let date):
            drilldownMoviesSheetMonth(date)
        case .location(let loc):
            drilldownMoviesSheetLocation(loc)
        case .suggestedBy(let name):
            drilldownMoviesSheetSuggestedBy(name)
        }
    }

    @ViewBuilder
    private func drilldownMoviesSheetMonth(_ date: Date) -> some View {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0

        let movies = filteredMovies.filter { movie in
            guard let d = movie.watchedDate else { return false }
            let c = calendar.dateComponents([.year, .month], from: d)
            return (c.year == year && c.month == month)
        }

        NavigationStack {
            List {
                if movies.isEmpty {
                    Text("Keine Filme in diesem Monat.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(monthFormatter.string(from: date))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func drilldownMoviesSheetLocation(_ loc: String) -> some View {
        let movies = filteredMovies.filter { normalizedLocation(for: $0) == loc }

        NavigationStack {
            List {
                if movies.isEmpty {
                    Text("Keine Filme an diesem Ort.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(loc)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }

    @ViewBuilder
    private func drilldownMoviesSheetSuggestedBy(_ name: String) -> some View {
        let movies = filteredMovies.filter { ($0.suggestedBy ?? "").lowercased() == name.lowercased() }

        NavigationStack {
            List {
                if movies.isEmpty {
                    Text("Keine Filme für diese Person.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle("Vorgeschlagen von")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }

    // MARK: - Movie Row

    @ViewBuilder
    private func movieRow(_ movie: Movie) -> some View {
        HStack(spacing: 12) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(movie.year).font(.caption).foregroundStyle(.secondary)

                    if let dateText = movie.watchedDateText {
                        Text("• \(dateText)").font(.caption).foregroundStyle(.secondary)
                    }

                    if let loc = movie.watchedLocation, !loc.isEmpty {
                        Text("• \(loc)").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let sugg = movie.suggestedBy,
                   !sugg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let avg = movie.averageRating ?? movie.tmdbRating {
                Text(String(format: "%.1f", avg))
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(MovieStore.preview())
            .environmentObject(UserStore())
    }
}
