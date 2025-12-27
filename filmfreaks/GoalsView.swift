//
//  GoalsView.swift
//  filmfreaks
//
//  Jahresziel + Custom Goals (Decade / Actor / Director / Genre / Keyword)
//  Step 3+4: Goal Types als enum + generische Persistenz (1 Payload, 1 UI-Renderer)
//

internal import SwiftUI

// MARK: - Shared UI Helper

/// Vorschläge aus den vorhandenen Filmen (offline), damit man ein Ziel schnell klicken kann.
struct PersonSuggestion: Identifiable, Hashable {
    let personId: Int
    let name: String
    let count: Int
    let profilePath: String?

    var id: Int { personId }
}

// MARK: - GoalsView

struct GoalsView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var goalsByYear: [Int: Int] = [:]

    // ✅ Custom Goals (v3+)
    @State private var customGoals: [ViewingCustomGoal] = []
    @State private var goalBeingEdited: ViewingCustomGoal? = nil
    @State private var selectedGoalForDetail: ViewingCustomGoal? = nil

    // TMDb Genres (für Genre-Goals)
    @State private var tmdbGenres: [TMDbGenre] = []
    @State private var isLoadingGenres = false

    // Matching-Metadaten-Enrichment (optional, nur wenn Goals es brauchen)
    @State private var isEnrichingMetadata = false

    // Sync handling (für Jahresziele + Custom Goals)
    @State private var syncCount: Int = 0
    private var isSyncingGoals: Bool { syncCount > 0 }

    private let yearlyGoalsStorageKey = "ViewingGoalsByYear.v1"
    private let defaultYearlyGoal = 50

    private var customGoalsStorageKey: String {
        let gid = movieStore.currentGroupId ?? ""
        return "ViewingCustomGoals.v3.\(gid)"
    }

    // MARK: - Derived Data

    private var moviesInSelectedYear: [Movie] {
        let cal = Calendar.current
        return movieStore.movies
            .compactMap { m in
                guard let d = m.watchedDate else { return nil }
                return cal.component(.year, from: d) == selectedYear ? m : nil
            }
            .sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    private var yearlyTarget: Int {
        goalsByYear[selectedYear] ?? defaultYearlyGoal
    }

    private var yearlyProgress: Double {
        guard yearlyTarget > 0 else { return 0 }
        return min(1.0, Double(moviesInSelectedYear.count) / Double(yearlyTarget))
    }

    private var availableDecades: [Int] {
        // Von vorhandenen Filmen ableiten, fallback: 1930–2020
        let years = movieStore.movies.compactMap { Int($0.year) }
        let minY = years.min() ?? 1930
        let maxY = years.max() ?? 2020
        let start = (minY / 10) * 10
        let end = (maxY / 10) * 10
        return stride(from: start, through: end, by: 10).map { $0 }.sorted()
    }

    private var actorSuggestions: [PersonSuggestion] {
        var map: [Int: (name: String, count: Int, profilePath: String?)] = [:]

        for m in moviesInSelectedYear {
            guard let cast = m.cast else { continue }
            for c in cast {
                guard c.personId > 0 else { continue }
                let current = map[c.personId]
                map[c.personId] = (name: c.name, count: (current?.count ?? 0) + 1, profilePath: current?.profilePath)
            }
        }

        return map
            .map { PersonSuggestion(personId: $0.key, name: $0.value.name, count: $0.value.count, profilePath: $0.value.profilePath) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            .prefix(20)
            .map { $0 }
    }

    private var directorSuggestions: [PersonSuggestion] {
        var map: [Int: (name: String, count: Int, profilePath: String?)] = [:]

        for m in moviesInSelectedYear {
            guard let directors = m.directors else { continue }
            for d in directors {
                guard d.personId > 0 else { continue }
                let current = map[d.personId]
                map[d.personId] = (name: d.name, count: (current?.count ?? 0) + 1, profilePath: current?.profilePath)
            }
        }

        return map
            .map { PersonSuggestion(personId: $0.key, name: $0.value.name, count: $0.value.count, profilePath: $0.value.profilePath) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            .prefix(20)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    yearlyGoalCard

                    customGoalsSection

                    Spacer(minLength: 12)
                }
                .padding()
            }
            .navigationTitle("Ziele")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            goalBeingEdited = ViewingCustomGoal(
                                type: .decade,
                                rule: .releaseDecade(availableDecades.last ?? 2000),
                                target: 10
                            )
                        } label: {
                            Label("Decade-Ziel", systemImage: ViewingCustomGoalType.decade.systemImage)
                        }

                        Button {
                            goalBeingEdited = ViewingCustomGoal(
                                type: .person,
                                rule: .person(id: 0, name: "", profilePath: nil),
                                target: 10
                            )
                        } label: {
                            Label("Darsteller-Ziel", systemImage: ViewingCustomGoalType.person.systemImage)
                        }

                        Button {
                            goalBeingEdited = ViewingCustomGoal(
                                type: .director,
                                rule: .director(id: 0, name: "", profilePath: nil),
                                target: 10
                            )
                        } label: {
                            Label("Regie-Ziel", systemImage: ViewingCustomGoalType.director.systemImage)
                        }

                        Button {
                            goalBeingEdited = ViewingCustomGoal(
                                type: .genre,
                                rule: .genre(id: tmdbGenres.first?.id ?? 0, name: tmdbGenres.first?.name ?? ""),
                                target: 10
                            )
                        } label: {
                            Label("Genre-Ziel", systemImage: ViewingCustomGoalType.genre.systemImage)
                        }

                        Button {
                            goalBeingEdited = ViewingCustomGoal(
                                type: .keyword,
                                rule: .keyword(id: 0, name: ""),
                                target: 10
                            )
                        } label: {
                            Label("Keyword-Ziel", systemImage: ViewingCustomGoalType.keyword.systemImage)
                        }

                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Neues Ziel")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSyncingGoals {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Ziele werden synchronisiert …")
                            .font(.caption)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
                    .padding()
                }
            }
            .sheet(item: $goalBeingEdited) { goal in
                CustomGoalEditorView(
                    initialGoal: goal,
                    availableDecades: availableDecades,
                    actorSuggestions: actorSuggestions,
                    directorSuggestions: directorSuggestions,
                    availableGenres: computedGenresForEditor(),
                    onCancel: { goalBeingEdited = nil },
                    onSave: { updated in
                        upsertCustomGoal(updated)
                        goalBeingEdited = nil
                        Task { await triggerMetadataEnrichmentIfNeeded() }
                    }
                )
            }
            .sheet(item: $selectedGoalForDetail) { goal in
                GoalDetailView(
                    goal: goal,
                    movies: matchingMovies(for: goal),
                    selectedYear: selectedYear
                )
            }
            .onAppear {
                loadYearlyGoals()
                loadCustomGoals()
                Task { await loadGenresIfNeeded() }
                Task { await triggerMetadataEnrichmentIfNeeded() }
                Task { await syncFromCloud() }
            }
            .onChange(of: selectedYear) { _, _ in
                Task { await triggerMetadataEnrichmentIfNeeded() }
            }
            .onChange(of: movieStore.currentGroupId) { _, _ in
                loadCustomGoals()
                Task { await syncFromCloud() }
            }
        }
    }

    // MARK: - UI Sections

    private var yearlyGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "Jahresziel \(selectedYear)")
                    .font(.headline)

                Spacer()

                Menu {
                    Button("Dieses Jahr") {
                        selectedYear = Calendar.current.component(.year, from: Date())
                    }
                    Divider()
                    ForEach(yearOptions(), id: \.self) { y in
                        Button { selectedYear = y } label: { Text(verbatim: "\(y)") }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: "\(selectedYear)")
                            .font(.subheadline.weight(.semibold))
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

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(moviesInSelectedYear.count) / \(yearlyTarget) Filme")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Stepper(
                        value: Binding(
                            get: { yearlyTarget },
                            set: { newValue in
                                setYearlyTarget(newValue)
                            }
                        ),
                        in: 1...500,
                        step: 1
                    ) {
                        EmptyView()
                    }
                    .labelsHidden()
                }

                ProgressView(value: yearlyProgress)
            }

            if !moviesInSelectedYear.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(moviesInSelectedYear.prefix(30)) { m in
                            posterTile(for: m)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text(verbatim: "Noch keine Filme in \(selectedYear) markiert.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }

    private var customGoalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom Goals")
                    .font(.headline)
                Spacer()
                Text("\(customGoals.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
            }

            if customGoals.isEmpty {
                Text("Leg dir Ziele an wie „10 Filme aus den 50ern“ oder „15 Filme von Nolan“ – und tracke sie wie dein Jahresziel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedCustomGoals()) { goal in
                        customGoalCard(goal)
                    }
                }
            }
        }
    }

    private func customGoalCard(_ goal: ViewingCustomGoal) -> some View {
        let matches = matchingMovies(for: goal)
        let progress = goal.target > 0 ? min(1.0, Double(matches.count) / Double(goal.target)) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                goalLeadingView(goal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text("\(matches.count) / \(goal.target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        goalBeingEdited = goal
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        deleteCustomGoal(goal)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }

            ProgressView(value: progress)

            if !matches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(matches.prefix(18)) { m in
                            posterTile(for: m)
                                .onTapGesture {
                                    selectedGoalForDetail = goal
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text(verbatim: "Noch keine passenden Filme in \(selectedYear).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                selectedGoalForDetail = goal
            } label: {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Passende Filme anzeigen")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
    }

    // MARK: - Small UI bits

    private func posterTile(for movie: Movie) -> some View {
        VStack(spacing: 4) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle().foregroundStyle(.gray.opacity(0.15))
                            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.15))
                    .frame(width: 60, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }
        }
    }

    @ViewBuilder
    private func goalLeadingView(_ goal: ViewingCustomGoal) -> some View {
        switch goal.type {
        case .decade:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                Image(systemName: ViewingCustomGoalType.decade.systemImage)
                    .foregroundStyle(.orange)
            }
            .frame(width: 44, height: 44)

        case .person, .director:
            if let path = goal.profilePath, !path.isEmpty,
               let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 10).foregroundStyle(.gray.opacity(0.15))
                            .overlay { ProgressView() }
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 10).foregroundStyle(.gray.opacity(0.15))
                            .overlay { Image(systemName: goal.type == .director ? ViewingCustomGoalType.director.systemImage : ViewingCustomGoalType.person.systemImage) }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 10).foregroundStyle(.gray.opacity(0.15))
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.12))
                    Image(systemName: goal.type == .director ? ViewingCustomGoalType.director.systemImage : ViewingCustomGoalType.person.systemImage)
                        .foregroundStyle(.blue)
                }
                .frame(width: 44, height: 44)
            }

        case .genre:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.14))
                Image(systemName: ViewingCustomGoalType.genre.systemImage)
                    .foregroundStyle(.purple)
            }
            .frame(width: 44, height: 44)

        case .keyword:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.green.opacity(0.14))
                Image(systemName: ViewingCustomGoalType.keyword.systemImage)
                    .foregroundStyle(.green)
            }
            .frame(width: 44, height: 44)
        }
    }

    // MARK: - Matching Logic

    private func matchingMovies(for goal: ViewingCustomGoal) -> [Movie] {
        let list = moviesInSelectedYear

        switch goal.rule {
        case .releaseDecade(let decadeStart):
            let minYear = decadeStart
            let maxYear = decadeStart + 9
            return list.filter { m in
                guard let y = Int(m.year) else { return false }
                return y >= minYear && y <= maxYear
            }

        case .person(let id, _, _):
            guard id > 0 else { return [] }
            return list.filter { m in
                (m.cast ?? []).contains(where: { $0.personId == id })
            }

        case .director(let id, _, _):
            guard id > 0 else { return [] }
            return list.filter { m in
                (m.directors ?? []).contains(where: { $0.personId == id })
            }

        case .genre(let id, let name):
            let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if id > 0 {
                return list.filter { m in
                    if let ids = m.genreIds, ids.contains(id) { return true }
                    return (m.genres ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            } else {
                return list.filter { m in
                    (m.genres ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            }

        case .keyword(let id, let name):
            let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if id > 0 {
                return list.filter { m in
                    if let ids = m.keywordIds, ids.contains(id) { return true }
                    return (m.keywords ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            } else {
                return list.filter { m in
                    (m.keywords ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            }
        }
    }

    // MARK: - Yearly Goal Persist/Sync

    private func yearOptions() -> [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 5)...(current + 1)).reversed()
    }

    private func loadYearlyGoals() {
        if let data = UserDefaults.standard.data(forKey: yearlyGoalsStorageKey),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            goalsByYear = decoded
        } else {
            goalsByYear = [:]
        }
    }

    private func persistYearlyGoals() {
        if let data = try? JSONEncoder().encode(goalsByYear) {
            UserDefaults.standard.set(data, forKey: yearlyGoalsStorageKey)
        }
    }

    private func setYearlyTarget(_ target: Int) {
        let clamped = max(1, target)
        goalsByYear[selectedYear] = clamped
        persistYearlyGoals()
        Task { await syncYearlyGoalToCloud(year: selectedYear, target: clamped) }
    }

    private func syncYearlyGoalToCloud(year: Int, target: Int) async {
        syncCount += 1
        defer { syncCount -= 1 }
        do {
            try await CloudKitGoalStore.shared.saveGoal(year: year, target: target, groupId: movieStore.currentGroupId)
        } catch {
            print("CloudKit save yearly goal error: \(error)")
        }
    }

    // MARK: - Custom Goals Persist/Sync

    private func sortedCustomGoals() -> [ViewingCustomGoal] {
        customGoals.sorted { a, b in
            if a.type != b.type { return a.type.rawValue < b.type.rawValue }
            return a.createdAt < b.createdAt
        }
    }

    private func loadCustomGoals() {
        // Local first
        if let data = UserDefaults.standard.data(forKey: customGoalsStorageKey),
           let payload = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data) {
            customGoals = stableDedupe(payload.goals)
            return
        }
        customGoals = []
    }

    private func persistCustomGoals() {
        let payload = ViewingCustomGoalsPayload(version: 3, goals: stableDedupe(customGoals))
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: customGoalsStorageKey)
        }
    }

    private func upsertCustomGoal(_ goal: ViewingCustomGoal) {
        var next = customGoals

        // Replace by ID (edit) OR by unique key (dedupe)
        if let idx = next.firstIndex(where: { $0.id == goal.id }) {
            next[idx] = goal
        } else if let key = goal.uniqueKey, let idx = next.firstIndex(where: { $0.uniqueKey == key }) {
            var g = goal
            // keep original ID for stability (links, sheets etc.)
            g.id = next[idx].id
            g.createdAt = next[idx].createdAt
            next[idx] = g
        } else {
            next.append(goal)
        }

        customGoals = stableDedupe(next)
        persistCustomGoals()
        Task { await syncCustomGoalsToCloud() }
    }

    private func deleteCustomGoal(_ goal: ViewingCustomGoal) {
        customGoals.removeAll { $0.id == goal.id }
        persistCustomGoals()
        Task { await syncCustomGoalsToCloud() }
    }

    private func stableDedupe(_ goals: [ViewingCustomGoal]) -> [ViewingCustomGoal] {
        var seen: Set<String> = []
        var out: [ViewingCustomGoal] = []
        out.reserveCapacity(goals.count)

        for g in goals.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let key = g.uniqueKey {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            out.append(g)
        }
        return out
    }

    private func syncCustomGoalsToCloud() async {
        syncCount += 1
        defer { syncCount -= 1 }
        do {
            let payload = ViewingCustomGoalsPayload(version: 3, goals: stableDedupe(customGoals))
            try await CloudKitGoalStore.shared.saveCustomGoals(payload, groupId: movieStore.currentGroupId)
        } catch {
            print("CloudKit save custom goals error: \(error)")
        }
    }

    private func syncFromCloud() async {
        syncCount += 1
        defer { syncCount -= 1 }

        do {
            let remoteYearly = try await CloudKitGoalStore.shared.fetchGoals(forGroupId: movieStore.currentGroupId)
            if !remoteYearly.isEmpty {
                goalsByYear = remoteYearly
                persistYearlyGoals()
            }

            let remoteCustom = try await CloudKitGoalStore.shared.fetchCustomGoals(forGroupId: movieStore.currentGroupId)
            if !remoteCustom.goals.isEmpty {
                customGoals = stableDedupe(remoteCustom.goals)
                persistCustomGoals()
            }

        } catch {
            print("CloudKit syncFromCloud error: \(error)")
        }
    }

    // MARK: - TMDb Genres

    private func computedGenresForEditor() -> [TMDbGenre] {
        if !tmdbGenres.isEmpty { return tmdbGenres }

        // Fallback: aus vorhandenen Filmen ableiten (ohne IDs)
        let names = Set(movieStore.movies.flatMap { $0.genres ?? [] }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return names.sorted().enumerated().map { idx, name in
            TMDbGenre(id: -(idx + 1), name: name) // negative IDs = local-only
        }
    }

    private func loadGenresIfNeeded() async {
        if !tmdbGenres.isEmpty || isLoadingGenres { return }
        isLoadingGenres = true
        defer { isLoadingGenres = false }

        // Cache aus UserDefaults
        let cacheKey = "TMDb.GenreList.de-DE.v1"
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([TMDbGenre].self, from: data),
           !decoded.isEmpty {
            tmdbGenres = decoded
            return
        }

        do {
            let fetched = try await TMDbAPI.shared.fetchMovieGenreList()
            await MainActor.run {
                tmdbGenres = fetched.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
                if let data = try? JSONEncoder().encode(tmdbGenres) {
                    UserDefaults.standard.set(data, forKey: cacheKey)
                }
            }
        } catch {
            // Nicht kritisch
            print("TMDb fetch genre list failed: \(error)")
        }
    }

    // MARK: - Metadata Enrichment (nur wenn nötig)

    private func needsDetailsEnrichment(for goalTypes: Set<ViewingCustomGoalType>) -> [Movie] {
        return moviesInSelectedYear.filter { m in
            guard m.tmdbId != nil else { return false }
            if goalTypes.contains(.director) {
                if (m.directors ?? []).isEmpty { return true }
            }
            if goalTypes.contains(.genre) {
                if (m.genreIds ?? []).isEmpty && (m.genres ?? []).isEmpty { return true }
            }
            if goalTypes.contains(.keyword) {
                if (m.keywordIds ?? []).isEmpty && (m.keywords ?? []).isEmpty { return true }
            }
            return false
        }
    }

    private func triggerMetadataEnrichmentIfNeeded() async {
        if isEnrichingMetadata { return }

        let typesNeeded = Set(customGoals.map { $0.type })
            .intersection([.director, .genre, .keyword])

        guard !typesNeeded.isEmpty else { return }

        let targets = needsDetailsEnrichment(for: typesNeeded)
        guard !targets.isEmpty else { return }

        isEnrichingMetadata = true
        defer { isEnrichingMetadata = false }

        // Wir holen pro Film einmal "große" Details (credits+keywords+genres),
        // weil wir damit alle Goal-Typen in einem Request abdecken.
        struct Update {
            let movieId: UUID
            let genreNames: [String]?
            let genreIds: [Int]?
            let keywordNames: [String]?
            let keywordIds: [Int]?
            let directors: [CastMember]?
        }

        var updates: [Update] = []
        updates.reserveCapacity(targets.count)

        await withTaskGroup(of: Update?.self) { group in
            for m in targets {
                guard let tmdbId = m.tmdbId else { continue }
                let movieId = m.id

                group.addTask {
                    do {
                        let details = try await TMDbAPI.shared.fetchMovieDetails(id: tmdbId)

                        let gNames = details.genres?.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let gIds = details.genres?.map { $0.id }

                        // NOTE: Avoid accessing `allKeywords` here.
                        // In Swift 6 language mode this can become a hard error if `allKeywords`
                        // is main-actor-isolated. We can safely merge the two possible arrays.
                        let kws = (details.keywords?.keywords ?? []) + (details.keywords?.results ?? [])
                        let kNames = kws.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let kIds = kws.map { $0.id }

                        let directors = details.credits?.crew
                            .filter { ($0.job ?? "").lowercased() == "director" }
                            .map { CastMember(personId: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)) }
                            .filter { !$0.name.isEmpty }

                        return Update(
                            movieId: movieId,
                            genreNames: gNames,
                            genreIds: gIds,
                            keywordNames: kNames,
                            keywordIds: kIds,
                            directors: directors
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await u in group {
                if let u { updates.append(u) }
            }
        }

        guard !updates.isEmpty else { return }

        // Apply in one shot (damit Persistenz/Cloud nicht pro Movie triggert)
        var updatedList = movieStore.movies
        var didChange = false

        for u in updates {
            guard let idx = updatedList.firstIndex(where: { $0.id == u.movieId }) else { continue }

            if typesNeeded.contains(.genre) {
                if let names = u.genreNames, !names.isEmpty {
                    if updatedList[idx].genres != names {
                        updatedList[idx].genres = names
                        didChange = true
                    }
                }
                if let ids = u.genreIds, !ids.isEmpty {
                    if updatedList[idx].genreIds != ids {
                        updatedList[idx].genreIds = ids
                        didChange = true
                    }
                }
            }

            if typesNeeded.contains(.keyword) {
                if let names = u.keywordNames, !names.isEmpty {
                    if updatedList[idx].keywords != names {
                        updatedList[idx].keywords = names
                        didChange = true
                    }
                }
                if let ids = u.keywordIds, !ids.isEmpty {
                    if updatedList[idx].keywordIds != ids {
                        updatedList[idx].keywordIds = ids
                        didChange = true
                    }
                }
            }

            if typesNeeded.contains(.director) {
                if let directors = u.directors, !directors.isEmpty {
                    if updatedList[idx].directors != directors {
                        updatedList[idx].directors = directors
                        didChange = true
                    }
                }
            }
        }

        if didChange {
            await MainActor.run {
                movieStore.movies = updatedList
            }
        }
    }
}

// MARK: - Goal Detail View

private struct GoalDetailView: View {
    let goal: ViewingCustomGoal
    let movies: [Movie]
    let selectedYear: Int

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(goal.title).font(.headline)
                        Spacer()
                        Text("\(movies.count) / \(goal.target)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if movies.isEmpty {
                    Text(verbatim: "Keine passenden Filme in \(selectedYear).")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { m in
                        HStack(spacing: 12) {
                            if let url = m.posterURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure:
                                        Rectangle().foregroundStyle(.gray.opacity(0.15))
                                            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                                    @unknown default:
                                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                                    }
                                }
                                .frame(width: 40, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Rectangle()
                                    .foregroundStyle(.gray.opacity(0.15))
                                    .frame(width: 40, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)

                                HStack(spacing: 6) {
                                    Text(m.year)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let date = m.watchedDateText {
                                        Text("• \(date)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            if let avg = m.averageRating ?? m.tmdbRating {
                                Text(String(format: "%.1f", avg))
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Passende Filme")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Editor

private struct CustomGoalEditorView: View {

    let initialGoal: ViewingCustomGoal
    let availableDecades: [Int]
    let actorSuggestions: [PersonSuggestion]
    let directorSuggestions: [PersonSuggestion]
    let availableGenres: [TMDbGenre]

    let onCancel: () -> Void
    let onSave: (ViewingCustomGoal) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var target: Int = 10

    // decade
    @State private var decadeStart: Int = 2000

    // person/director
    @State private var personQuery: String = ""
    @State private var isSearchingPerson = false
    @State private var personResults: [TMDbPersonSummary] = []
    @State private var selectedPersonId: Int = 0
    @State private var selectedPersonName: String = ""
    @State private var selectedProfilePath: String? = nil

    // genre
    @State private var selectedGenreId: Int = 0
    @State private var selectedGenreName: String = ""

    // keyword
    @State private var keywordQuery: String = ""
    @State private var isSearchingKeyword = false
    @State private var keywordResults: [TMDbKeywordSummary] = []
    @State private var selectedKeywordId: Int = 0
    @State private var selectedKeywordName: String = ""

    init(
        initialGoal: ViewingCustomGoal,
        availableDecades: [Int],
        actorSuggestions: [PersonSuggestion],
        directorSuggestions: [PersonSuggestion],
        availableGenres: [TMDbGenre],
        onCancel: @escaping () -> Void,
        onSave: @escaping (ViewingCustomGoal) -> Void
    ) {
        self.initialGoal = initialGoal
        self.availableDecades = availableDecades
        self.actorSuggestions = actorSuggestions
        self.directorSuggestions = directorSuggestions
        self.availableGenres = availableGenres
        self.onCancel = onCancel
        self.onSave = onSave

        _target = State(initialValue: initialGoal.target)

        switch initialGoal.rule {
        case .releaseDecade(let d):
            _decadeStart = State(initialValue: d)

        case .person(let id, let name, let profilePath):
            _selectedPersonId = State(initialValue: id)
            _selectedPersonName = State(initialValue: name)
            _selectedProfilePath = State(initialValue: profilePath)

        case .director(let id, let name, let profilePath):
            _selectedPersonId = State(initialValue: id)
            _selectedPersonName = State(initialValue: name)
            _selectedProfilePath = State(initialValue: profilePath)

        case .genre(let id, let name):
            _selectedGenreId = State(initialValue: id)
            _selectedGenreName = State(initialValue: name)

        case .keyword(let id, let name):
            _selectedKeywordId = State(initialValue: id)
            _selectedKeywordName = State(initialValue: name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Ziel") {
                    Stepper(value: $target, in: 1...500) {
                        Text("\(target) Filme")
                    }
                }

                switch initialGoal.type {
                case .decade:
                    decadeEditor

                case .person:
                    personEditor(
                        title: "Darsteller",
                        placeholder: "Name suchen …",
                        suggestions: actorSuggestions,
                        preferDepartment: nil
                    )

                case .director:
                    personEditor(
                        title: "Regie",
                        placeholder: "Regisseur suchen …",
                        suggestions: directorSuggestions,
                        preferDepartment: "Directing"
                    )

                case .genre:
                    genreEditor

                case .keyword:
                    keywordEditor
                }
            }
            .navigationTitle("Ziel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(buildUpdatedGoal())
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Editor Sections

    private var decadeEditor: some View {
        Section("Decade") {
            Picker("Jahrzehnt", selection: $decadeStart) {
                ForEach(availableDecades, id: \.self) { d in
                        // `Text("\(d)")` inside SwiftUI can localize numbers (e.g. "1.950").
                        // We want plain digits for years.
                        Text(verbatim: "\(d)–\(d + 9)").tag(d)
                }
            }
        }
    }

    private func personEditor(
        title: String,
        placeholder: String,
        suggestions: [PersonSuggestion],
        preferDepartment: String?
    ) -> some View {
        Section(title) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(placeholder, text: $personQuery)
                    .textInputAutocapitalization(.words)
                    .onChange(of: personQuery) { _, newValue in
                        Task { await searchPersonIfNeeded(query: newValue, preferDepartment: preferDepartment) }
                    }

                if selectedPersonId > 0 {
                    HStack(spacing: 10) {
                        if let p = selectedProfilePath, let url = URL(string: "https://image.tmdb.org/t/p/w185\(p)") {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                        .overlay { ProgressView() }
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                        .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                                @unknown default:
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.gray.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPersonName)
                                .font(.subheadline.weight(.semibold))
                            Text("Ausgewählt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            selectedPersonId = 0
                            selectedPersonName = ""
                            selectedProfilePath = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isSearchingPerson {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Suche …").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if personQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, selectedPersonId == 0 {
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "Vorschläge aus \(Calendar.current.component(.year, from: Date())) / deiner Auswahl:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                // Use `enumerated()` as the identity so taps stay correct even if
                                // we accidentally have duplicate personIds in suggestions.
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                                    Button {
                                        selectedPersonId = s.personId
                                        selectedPersonName = s.name
                                        selectedProfilePath = s.profilePath
                                    } label: {
                                        HStack {
                                            Text(s.name)
                                            Spacer()
                                            Text("\(s.count)x")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                        }
                    } else {
                        Text("Tipp: Such oben nach einem Namen oder öffne ein paar Filmdetails, damit Cast/Regie lokal gespeichert wird.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if !personResults.isEmpty {
                            ForEach(filteredPersonResults(preferDepartment: preferDepartment)) { p in
                                Button {
                                    selectedPersonId = p.id
                                    selectedPersonName = p.name
                                    selectedProfilePath = p.profile_path
                                    personQuery = ""
                                    personResults = []
                                } label: {
                                    HStack(spacing: 10) {
                                    if let path = p.profile_path, let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                                    .overlay { ProgressView() }
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                                    .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                                            @unknown default:
                                                RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                            }
                                        }
                                        .frame(width: 34, height: 34)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .foregroundStyle(.gray.opacity(0.15))
                                            .frame(width: 34, height: 34)
                                            .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name)
                                        if let dep = p.known_for_department, !dep.isEmpty {
                                            Text(dep)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                        }
                    } else if !personQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSearchingPerson {
                        Text("Keine Treffer.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var genreEditor: some View {
        Section("Genre") {
            if availableGenres.isEmpty {
                Text("Keine Genres verfügbar. (TMDb konnte nicht geladen werden)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Genre", selection: Binding(
                    get: { selectedGenreId },
                    set: { newValue in
                        selectedGenreId = newValue
                        selectedGenreName = availableGenres.first(where: { $0.id == newValue })?.name ?? ""
                    }
                )) {
                    ForEach(availableGenres) { g in
                        Text(g.name).tag(g.id)
                    }
                }
                .onAppear {
                    if selectedGenreId == 0 {
                        selectedGenreId = availableGenres.first?.id ?? 0
                        selectedGenreName = availableGenres.first?.name ?? ""
                    }
                }
            }
        }
    }

    private var keywordEditor: some View {
        Section("Keyword") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Keyword suchen …", text: $keywordQuery)
                    .textInputAutocapitalization(.never)
                    .onChange(of: keywordQuery) { _, newValue in
                        Task { await searchKeywordIfNeeded(query: newValue) }
                    }

                if selectedKeywordId > 0 {
                    HStack {
                        Text(selectedKeywordName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(role: .destructive) {
                            selectedKeywordId = 0
                            selectedKeywordName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isSearchingKeyword {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Suche …").font(.caption).foregroundStyle(.secondary)
                    }
                }

                    if !keywordResults.isEmpty {
                        // Use `enumerated()` as identity to avoid any weirdness if TMDb ever returns duplicates.
                        ForEach(Array(keywordResults.enumerated()), id: \.offset) { _, k in
                            Button {
                                selectedKeywordId = k.id
                                selectedKeywordName = k.name
                                keywordQuery = ""
                                keywordResults = []
                            } label: {
                                HStack {
                                    Text(k.name)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !keywordQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSearchingKeyword {
                    Text("Keine Treffer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Networking

    private func filteredPersonResults(preferDepartment: String?) -> [TMDbPersonSummary] {
        guard let preferDepartment, !preferDepartment.isEmpty else { return personResults }
        let preferred = personResults.filter { ($0.known_for_department ?? "").lowercased() == preferDepartment.lowercased() }
        let rest = personResults.filter { ($0.known_for_department ?? "").lowercased() != preferDepartment.lowercased() }
        return preferred + rest
    }

    private func searchPersonIfNeeded(query: String, preferDepartment: String?) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            await MainActor.run { personResults = [] }
            return
        }

        await MainActor.run { isSearchingPerson = true }
        defer { Task { @MainActor in isSearchingPerson = false } }

        do {
            let results = try await TMDbAPI.shared.searchPerson(name: trimmed)
            await MainActor.run {
                // Für Directors gerne Directing zuerst – aber alles anzeigen
                personResults = results
            }
        } catch {
            await MainActor.run { personResults = [] }
        }
    }

    private func searchKeywordIfNeeded(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            await MainActor.run { keywordResults = [] }
            return
        }

        await MainActor.run { isSearchingKeyword = true }
        defer { Task { @MainActor in isSearchingKeyword = false } }

        do {
            let results = try await TMDbAPI.shared.searchKeywords(query: trimmed)
            await MainActor.run {
                keywordResults = Array(results.prefix(20))
            }
        } catch {
            await MainActor.run { keywordResults = [] }
        }
    }

    // MARK: - Build / Validation

    private var canSave: Bool {
        if target < 1 { return false }
        switch initialGoal.type {
        case .decade:
            return true
        case .person:
            return selectedPersonId > 0 && !selectedPersonName.isEmpty
        case .director:
            return selectedPersonId > 0 && !selectedPersonName.isEmpty
        case .genre:
            return selectedGenreId != 0 && !selectedGenreName.isEmpty
        case .keyword:
            return selectedKeywordId > 0 && !selectedKeywordName.isEmpty
        }
    }

    private func buildUpdatedGoal() -> ViewingCustomGoal {
        var updated = initialGoal
        updated.target = target

        switch initialGoal.type {
        case .decade:
            updated.type = .decade
            updated.rule = .releaseDecade(decadeStart)

        case .person:
            updated.type = .person
            updated.rule = .person(id: selectedPersonId, name: selectedPersonName, profilePath: selectedProfilePath)

        case .director:
            updated.type = .director
            updated.rule = .director(id: selectedPersonId, name: selectedPersonName, profilePath: selectedProfilePath)

        case .genre:
            updated.type = .genre
            updated.rule = .genre(id: selectedGenreId, name: selectedGenreName)

        case .keyword:
            updated.type = .keyword
            updated.rule = .keyword(id: selectedKeywordId, name: selectedKeywordName)
        }

        return updated
    }
}

// MARK: - Preview

#Preview {
    GoalsView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
}
