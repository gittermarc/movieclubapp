//
//  GoalsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.12.25.
//

internal import SwiftUI

// MARK: - Shared helper type (file-scope, NOT private)
struct ActorSuggestion: Identifiable, Hashable {
    let personId: Int
    let name: String
    let count: Int
    var id: Int { personId }
}

struct GoalsView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var goalsByYear: [Int: Int] = [:]

    // ✅ Step 3: Ein Array für alle Custom Goals
    @State private var customGoals: [ViewingCustomGoal] = []

    // Editor states
    @State private var goalBeingEdited: ViewingCustomGoal? = nil
    @State private var isEditingExistingGoal: Bool = false

    // Detail sheet
    @State private var selectedGoalForDetail: ViewingCustomGoal? = nil

    // Sync handling (für Jahresziele + Custom Goals)
    @State private var syncCount: Int = 0
    private var isSyncingGoals: Bool { syncCount > 0 }

    private let storageKey = "ViewingGoalsByYear"
    private let defaultGoal = 50

    // ✅ neuer, versionierter Cache-Key pro Gruppe (v3)
    private var customGoalsStorageKey: String {
        let gid = movieStore.currentGroupId ?? ""
        return "ViewingCustomGoals.Payload.v3.\(gid)"
    }

    // ✅ alter Key aus Step 2 (v2 Payload)
    private var legacyCustomGoalsStorageKeyV2: String {
        let gid = movieStore.currentGroupId ?? ""
        return "ViewingCustomGoals.Payload.v2.\(gid)"
    }

    // ✅ alter Key aus Step 1 (nur Decade)
    private var legacyDecadeGoalsStorageKeyV1: String {
        let gid = movieStore.currentGroupId ?? ""
        return "ViewingCustomGoals.Decade.v1.\(gid)"
    }

    // MARK: - Abgeleitete Werte

    private var availableYears: [Int] {
        let calendar = Calendar.current

        let yearsFromMovies = movieStore.movies.compactMap { movie -> Int? in
            guard let date = movie.watchedDate else { return nil }
            return calendar.component(.year, from: date)
        }

        let yearsFromGoals = goalsByYear.keys

        var set = Set<Int>(yearsFromMovies + yearsFromGoals)
        let currentYear = Calendar.current.component(.year, from: Date())
        set.insert(currentYear)

        return Array(set).sorted()
    }

    private var moviesInSelectedYear: [Movie] {
        let calendar = Calendar.current
        return movieStore.movies.compactMap { movie in
            guard let date = movie.watchedDate else { return nil }
            let year = calendar.component(.year, from: date)
            return year == selectedYear ? movie : nil
        }
        .sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    private var targetForSelectedYear: Int {
        goalsByYear[selectedYear] ?? defaultGoal
    }

    private var progressText: String {
        let seen = moviesInSelectedYear.count
        let target = max(targetForSelectedYear, 1)
        let percent = (Double(seen) / Double(target)) * 100.0
        return String(format: "%.0f %% erreicht", min(percent, 100.0))
    }

    private var customGoalsSorted: [ViewingCustomGoal] {
        customGoals.sorted { a, b in
            if a.type != b.type { return a.type.rawValue < b.type.rawValue }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        headerSection
                        gridSection
                        customGoalsSection

                        Spacer(minLength: 16)
                    }
                    .padding()
                }

                if isSyncingGoals {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Ziele werden synchronisiert …")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4)
                            .padding()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Ziele")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isEditingExistingGoal = false
                            goalBeingEdited = ViewingCustomGoal(
                                type: .decade,
                                rule: .releaseDecade(suggestedDefaultDecade()),
                                target: 10
                            )
                        } label: {
                            Label("Decade-Ziel", systemImage: ViewingCustomGoalType.decade.systemImage)
                        }

                        Button {
                            isEditingExistingGoal = false
                            goalBeingEdited = ViewingCustomGoal(
                                type: .person,
                                rule: .person(id: 0, name: "", profilePath: nil),
                                target: 10
                            )
                        } label: {
                            Label("Darsteller-Ziel", systemImage: ViewingCustomGoalType.person.systemImage)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neues Ziel")
                }
            }
            .onAppear {
                loadGoals()
                loadCustomGoals()

                if !availableYears.contains(selectedYear),
                   let first = availableYears.first {
                    selectedYear = first
                }
            }
            .sheet(item: $goalBeingEdited) { goal in
                CustomGoalEditorView(
                    initialGoal: goal,
                    availableDecades: availableDecades(),
                    suggestions: actorSuggestionsForSelectedYear(),
                    onCancel: { goalBeingEdited = nil },
                    onSave: { updated in
                        upsertCustomGoal(updated, editingExisting: isEditingExistingGoal)
                        goalBeingEdited = nil
                    }
                )
            }
            .sheet(item: $selectedGoalForDetail) { goal in
                customGoalDetailSheet(goal: goal)
            }
        }
    }

    // MARK: - Header / Ziel-Einstellungen

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text("Jahr")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableYears, id: \.self) { year in
                            let isSelected = year == selectedYear

                            Button { selectedYear = year } label: {
                                Text(String(year))
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 999)
                                            .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 999)
                                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                                    )
                                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ziel für \(selectedYear.formatted(.number.grouping(.never)))")
                    .font(.headline)

                HStack {
                    let binding = Binding<Int>(
                        get: { targetForSelectedYear },
                        set: { newValue in
                            let clamped = max(newValue, 1)
                            goalsByYear[selectedYear] = clamped
                            goalChanged(forYear: selectedYear, target: clamped)
                        }
                    )

                    Stepper(value: binding, in: 1...500) {
                        Text("\(binding.wrappedValue) Filme")
                            .font(.subheadline)
                    }

                    Spacer()
                }

                let seen = moviesInSelectedYear.count
                let target = max(targetForSelectedYear, 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bisher gesehen: \(seen) von \(targetForSelectedYear)")
                        .font(.subheadline)

                    GeometryReader { geo in
                        let width = geo.size.width
                        let fraction = min(Double(seen) / Double(target), 1.0)
                        let filledWidth = width * fraction

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: max(0, filledWidth))
                        }
                    }
                    .frame(height: 8)

                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: - Grid mit Covern / Platzhaltern

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filme in \(selectedYear.formatted(.number.grouping(.never)))")
                .font(.headline)

            let seenMovies = moviesInSelectedYear
            let target = max(targetForSelectedYear, seenMovies.count)

            if target == 0 {
                Text("Lege oben ein Ziel fest, um mit der Challenge zu starten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 8)],
                    spacing: 12
                ) {
                    ForEach(0..<target, id: \.self) { index in
                        if index < seenMovies.count {
                            let movie = seenMovies[index]

                            if let binding = binding(for: movie) {
                                NavigationLink {
                                    MovieDetailView(movie: binding, isBacklog: false)
                                } label: {
                                    posterTile(for: movie)
                                }
                                .buttonStyle(.plain)
                            } else {
                                posterTile(for: movie)
                            }

                        } else {
                            placeholderTile()
                        }
                    }
                }
            }
        }
    }

    // MARK: - ✅ Custom Goals Section (generisch)

    private var customGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("Eigene Ziele")
                    .font(.headline)
                Spacer()

                Menu {
                    Button {
                        isEditingExistingGoal = false
                        goalBeingEdited = ViewingCustomGoal(
                            type: .decade,
                            rule: .releaseDecade(suggestedDefaultDecade()),
                            target: 10
                        )
                    } label: { Label("Decade-Ziel", systemImage: ViewingCustomGoalType.decade.systemImage) }

                    Button {
                        isEditingExistingGoal = false
                        goalBeingEdited = ViewingCustomGoal(
                            type: .person,
                            rule: .person(id: 0, name: "", profilePath: nil),
                            target: 10
                        )
                    } label: { Label("Darsteller-Ziel", systemImage: ViewingCustomGoalType.person.systemImage) }

                } label: {
                    Label("Hinzufügen", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            if customGoals.isEmpty {
                Text("Lege eigene Ziele an, z.B. „10 Filme aus den 50ern“ oder „15 Filme mit Leonardo DiCaprio“ – Fortschritt zählt für das aktuell gewählte Jahr.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(customGoalsSorted) { goal in
                        customGoalCard(goal: goal)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func customGoalCard(goal: ViewingCustomGoal) -> some View {
        let matches = matchingMovies(for: goal)
        let seen = matches.count
        let target = max(goal.target, 1)
        let fraction = min(Double(seen) / Double(target), 1.0)
        let percentText = String(format: "%.0f %% erreicht", fraction * 100.0)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {

                goalLeadingView(goal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text("\(seen) von \(goal.target) im Jahr \(selectedYear)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        isEditingExistingGoal = true
                        goalBeingEdited = goal
                    } label: { Label("Bearbeiten", systemImage: "pencil") }

                    Button(role: .destructive) {
                        deleteCustomGoal(goal)
                    } label: { Label("Löschen", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let filledWidth = width * fraction

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: max(0, filledWidth))
                }
            }
            .frame(height: 8)

            HStack {
                Text(percentText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    selectedGoalForDetail = goal
                } label: {
                    Text("Matching Movies")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            if matches.isEmpty {
                Text("Noch keine passenden Filme im gewählten Jahr.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(matches.prefix(12), id: \.id) { movie in
                            if let binding = binding(for: movie) {
                                NavigationLink {
                                    MovieDetailView(movie: binding, isBacklog: false)
                                } label: {
                                    posterThumb(for: movie)
                                }
                                .buttonStyle(.plain)
                            } else {
                                posterThumb(for: movie)
                            }
                        }

                        if matches.count > 12 {
                            Text("+\(matches.count - 12)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func goalLeadingView(_ goal: ViewingCustomGoal) -> some View {
        switch goal.type {
        case .decade:
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: ViewingCustomGoalType.decade.systemImage)
                        .foregroundStyle(Color.accentColor)
                }

        case .person:
            actorAvatar(profilePath: goal.profilePath, fallbackSystemName: "person.fill")
        }
    }

    // MARK: - Thumbs / Avatar

    @ViewBuilder
    private func posterThumb(for movie: Movie) -> some View {
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
                        .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                @unknown default:
                    Rectangle().foregroundStyle(.gray.opacity(0.2))
                }
            }
            .frame(width: 52, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Rectangle()
                .foregroundStyle(.gray.opacity(0.15))
                .frame(width: 52, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder
    private func actorAvatar(profilePath: String?, fallbackSystemName: String) -> some View {
        if let p = profilePath,
           let url = URL(string: "https://image.tmdb.org/t/p/w185\(p)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle().fill(Color.gray.opacity(0.2))
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Circle().fill(Color.gray.opacity(0.2))
                        .overlay { Image(systemName: fallbackSystemName).foregroundStyle(.secondary) }
                @unknown default:
                    Circle().fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay { Image(systemName: fallbackSystemName).foregroundStyle(.secondary) }
        }
    }

    // MARK: - Detail Sheet (generisch)

    @ViewBuilder
    private func customGoalDetailSheet(goal: ViewingCustomGoal) -> some View {
        let matches = matchingMovies(for: goal)

        NavigationStack {
            List {
                if matches.isEmpty {
                    Text("Keine passenden Filme im Jahr \(selectedYear).")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(matches) { movie in
                        if let binding = binding(for: movie) {
                            NavigationLink {
                                MovieDetailView(movie: binding, isBacklog: false)
                            } label: {
                                movieRow(movie)
                            }
                        } else {
                            movieRow(movie)
                        }
                    }
                }
            }
            .navigationTitle(goal.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedGoalForDetail = nil }
                }
            }
        }
    }

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
                    Text(movie.year)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dateText = movie.watchedDateText {
                        Text("• \(dateText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

    // MARK: - Matching Logic (generisch)

    private func matchingMovies(for goal: ViewingCustomGoal) -> [Movie] {
        switch goal.rule {

        case .releaseDecade(let decadeStart):
            let decadeEnd = decadeStart + 9
            return moviesInSelectedYear.filter { movie in
                guard let releaseYear = Int(movie.year.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
                return releaseYear >= decadeStart && releaseYear <= decadeEnd
            }

        case .person(let id, _, _):
            guard id > 0 else { return [] }
            return moviesInSelectedYear.filter { movie in
                guard let cast = movie.cast else { return false }
                return cast.contains(where: { $0.personId == id })
            }
        }
    }

    // MARK: - Decades helper

    private func availableDecades() -> [Int] {
        var decades = Array(stride(from: 1920, through: 2030, by: 10))

        let fromMovies: [Int] = movieStore.movies.compactMap { movie in
            guard let y = Int(movie.year.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return (y / 10) * 10
        }

        decades.append(contentsOf: fromMovies)
        decades = Array(Set(decades)).sorted()
        return decades
    }

    private func suggestedDefaultDecade() -> Int {
        let decades = moviesInSelectedYear.compactMap { movie -> Int? in
            guard let y = Int(movie.year.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return (y / 10) * 10
        }

        guard !decades.isEmpty else { return 1990 }

        var counts: [Int: Int] = [:]
        for d in decades { counts[d, default: 0] += 1 }

        return counts.sorted { a, b in
            if a.value != b.value { return a.value > b.value }
            return a.key > b.key
        }.first?.key ?? 1990
    }

    // MARK: - Actor Suggestions (offline / ohne TMDb Search)

    private func actorSuggestionsForSelectedYear() -> [ActorSuggestion] {
        var counts: [Int: (name: String, count: Int)] = [:]

        for movie in moviesInSelectedYear {
            guard let cast = movie.cast else { continue }
            for member in cast {
                guard member.personId > 0 else { continue }
                let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                if var existing = counts[member.personId] {
                    existing.count += 1
                    counts[member.personId] = existing
                } else {
                    counts[member.personId] = (name: trimmed, count: 1)
                }
            }
        }

        return counts
            .map { ActorSuggestion(personId: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(20)
            .map { $0 }
    }

    // MARK: - Upsert / Delete + Persist (generisch)

    private func upsertCustomGoal(_ goal: ViewingCustomGoal, editingExisting: Bool) {
        var next = customGoals

        if editingExisting {
            if let idx = next.firstIndex(where: { $0.id == goal.id }) {
                next[idx] = goal
            } else {
                next.append(goal)
            }
        } else {
            next.append(goal)
        }

        // Dedup by semantic key (decade/person)
        var byKey: [String: ViewingCustomGoal] = [:]
        var fallbacks: [ViewingCustomGoal] = []

        for g in next {
            if let key = g.uniqueKey {
                byKey[key] = g
            } else {
                fallbacks.append(g)
            }
        }

        customGoals = Array(byKey.values) + fallbacks
        persistCustomGoals()
    }

    private func deleteCustomGoal(_ goal: ViewingCustomGoal) {
        customGoals.removeAll { $0.id == goal.id }
        persistCustomGoals()
    }

    private func persistCustomGoals() {
        saveCustomGoalsToCache()

        let groupId = movieStore.currentGroupId ?? ""
        beginSync()
        Task {
            do {
                let payload = ViewingCustomGoalsPayload(version: 3, goals: customGoals)
                try await CloudKitGoalStore.shared.saveCustomGoals(payload, groupId: groupId)
            } catch {
                print("CloudKit ViewingCustomGoals save error: \(error)")
            }
            await MainActor.run { endSync() }
        }
    }

    // MARK: - Binding-Helfer

    private func binding(for movie: Movie) -> Binding<Movie>? {
        guard let index = movieStore.movies.firstIndex(where: { $0.id == movie.id }) else {
            return nil
        }
        return $movieStore.movies[index]
    }

    // MARK: - Kacheln

    @ViewBuilder
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
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.15))
                    .aspectRatio(2.0 / 3.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }
        }
    }

    @ViewBuilder
    private func placeholderTile() -> some View {
        Rectangle()
            .foregroundStyle(.gray.opacity(0.08))
            .aspectRatio(2.0 / 3.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "popcorn")
                        .font(.title3)
                    Text("frei")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - Persistence (lokal + CloudKit) – Jahresziele

    private func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            goalsByYear = decoded
        } else {
            goalsByYear = [:]
        }

        let groupId = movieStore.currentGroupId ?? ""

        beginSync()
        Task {
            do {
                let remote = try await CloudKitGoalStore.shared.fetchGoals(forGroupId: groupId)
                await MainActor.run {
                    self.goalsByYear = remote
                    self.saveGoalsToCache()
                    self.endSync()
                }
            } catch {
                print("CloudKit ViewingGoal fetch error: \(error)")
                await MainActor.run { self.endSync() }
            }
        }
    }

    private func saveGoalsToCache() {
        if let data = try? JSONEncoder().encode(goalsByYear) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func goalChanged(forYear year: Int, target: Int) {
        saveGoalsToCache()
        let groupId = movieStore.currentGroupId ?? ""

        beginSync()
        Task {
            do {
                try await CloudKitGoalStore.shared.saveGoal(year: year, target: target, groupId: groupId)
            } catch {
                print("CloudKit ViewingGoal save error: \(error)")
            }
            await MainActor.run { self.endSync() }
        }
    }

    // MARK: - Persistence (lokal + CloudKit) – Custom Goals (v3)

    private func loadCustomGoals() {
        // 1) Local v3 cache
        if let data = UserDefaults.standard.data(forKey: customGoalsStorageKey),
           let decoded = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data) {
            customGoals = decoded.goals
        } else {
            // 2) Local v2 cache (Step 2)
            if let v2Data = UserDefaults.standard.data(forKey: legacyCustomGoalsStorageKeyV2) {
                if let decodedV2 = try? JSONDecoder().decode(ViewingCustomGoalsPayloadV2.self, from: v2Data) {
                    let v3 = decodedV2.toV3()
                    customGoals = v3.goals
                    saveCustomGoalsToCache()
                } else if let decodedAsV3 = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: v2Data) {
                    // Falls der Key mal „falsch“ weiterverwendet wurde
                    customGoals = decodedAsV3.goals
                    saveCustomGoalsToCache()
                } else {
                    customGoals = []
                }
            } else {
                // 3) Local legacy v1 cache (Step 1 – [DecadeGoal])
                if let legacyData = UserDefaults.standard.data(forKey: legacyDecadeGoalsStorageKeyV1),
                   let legacyDecades = try? JSONDecoder().decode([DecadeGoal].self, from: legacyData) {
                    customGoals = legacyDecades.map { ViewingCustomGoal(from: $0) }
                    saveCustomGoalsToCache()
                } else {
                    customGoals = []
                }
            }
        }

        // 4) Cloud (authoritative)
        let groupId = movieStore.currentGroupId ?? ""

        beginSync()
        Task {
            do {
                let remote = try await CloudKitGoalStore.shared.fetchCustomGoals(forGroupId: groupId)
                await MainActor.run {
                    self.customGoals = remote.goals
                    self.saveCustomGoalsToCache()
                    self.endSync()
                }
            } catch {
                print("CloudKit ViewingCustomGoals fetch error: \(error)")
                await MainActor.run { self.endSync() }
            }
        }
    }

    private func saveCustomGoalsToCache() {
        let payload = ViewingCustomGoalsPayload(version: 3, goals: customGoals)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: customGoalsStorageKey)
        }
    }

    private func beginSync() { syncCount += 1 }
    private func endSync() { syncCount = max(0, syncCount - 1) }
}

// MARK: - Custom Goal Editor (Decade + Person)

private struct CustomGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let initialGoal: ViewingCustomGoal
    private let availableDecades: [Int]
    private let suggestions: [ActorSuggestion]
    private let onCancel: () -> Void
    private let onSave: (ViewingCustomGoal) -> Void

    // Shared
    @State private var target: Int

    // Decade
    @State private var decadeStart: Int

    // Person selection
    @State private var selectedPersonId: Int
    @State private var selectedPersonName: String
    @State private var selectedProfilePath: String?

    // Person search
    @State private var query: String = ""
    @State private var results: [TMDbPersonSummary] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    init(
        initialGoal: ViewingCustomGoal,
        availableDecades: [Int],
        suggestions: [ActorSuggestion],
        onCancel: @escaping () -> Void,
        onSave: @escaping (ViewingCustomGoal) -> Void
    ) {
        self.initialGoal = initialGoal
        self.availableDecades = availableDecades
        self.suggestions = suggestions
        self.onCancel = onCancel
        self.onSave = onSave

        _target = State(initialValue: initialGoal.target)

        switch initialGoal.rule {
        case .releaseDecade(let d):
            _decadeStart = State(initialValue: d)
            _selectedPersonId = State(initialValue: 0)
            _selectedPersonName = State(initialValue: "")
            _selectedProfilePath = State(initialValue: nil)
            _query = State(initialValue: "")

        case .person(let id, let name, let p):
            _decadeStart = State(initialValue: availableDecades.first ?? 1990)
            _selectedPersonId = State(initialValue: id)
            _selectedPersonName = State(initialValue: name)
            _selectedProfilePath = State(initialValue: p)
            _query = State(initialValue: name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch initialGoal.type {

                case .decade:
                    Section("Decade") {
                        Picker("Jahrzehnt", selection: $decadeStart) {
                            ForEach(availableDecades, id: \.self) { d in
                                Text("\(d)–\(d + 9)").tag(d)
                            }
                        }
                    }

                case .person:
                    Section("Darsteller") {
                        TextField("Suche nach Name (TMDb)", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: query) { _, newValue in
                                scheduleSearch(for: newValue)
                            }

                        if isSearching {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Suche …")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let err = searchError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if selectedPersonId > 0, !selectedPersonName.isEmpty {
                            HStack(spacing: 10) {
                                avatar(profilePath: selectedProfilePath)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedPersonName)
                                        .font(.subheadline.weight(.semibold))
                                    Text("TMDb ID: \(selectedPersonId)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    selectedPersonId = 0
                                    selectedPersonName = ""
                                    selectedProfilePath = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("Wähle eine Person aus der Suche oder aus den Vorschlägen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !suggestions.isEmpty && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Section("Vorschläge aus deinem Jahr") {
                            ForEach(suggestions) { s in
                                Button {
                                    selectedPersonId = s.personId
                                    selectedPersonName = s.name
                                    selectedProfilePath = nil
                                } label: {
                                    HStack {
                                        Text(s.name)
                                        Spacer()
                                        Text("(\(s.count))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !results.isEmpty {
                        Section("TMDb Ergebnisse") {
                            ForEach(results) { p in
                                Button {
                                    selectedPersonId = p.id
                                    selectedPersonName = p.name
                                    selectedProfilePath = p.profile_path
                                } label: {
                                    HStack(spacing: 10) {
                                        avatar(profilePath: p.profile_path)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name)
                                                .font(.subheadline.weight(.semibold))
                                            if let dept = p.known_for_department, !dept.isEmpty {
                                                Text(dept)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if let pop = p.popularity {
                                            Text(String(format: "%.1f", pop))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Ziel") {
                    Stepper(value: $target, in: 1...500) {
                        Text("\(target) Filme")
                    }
                }

                Section {
                    Text(tipText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(initialGoal.type.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        searchTask?.cancel()
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let updated = buildUpdatedGoal()
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .onAppear {
                // Autosearch, wenn wir eine Person vorbefüllt haben
                if initialGoal.type == .person,
                   !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   results.isEmpty {
                    scheduleSearch(for: query)
                }
            }
        }
    }

    private var tipText: String {
        switch initialGoal.type {
        case .decade:
            return "Tipp: Gezählt werden Filme, die du im aktuell gewählten Jahr gesehen hast – und deren Release-Year in das Jahrzehnt fällt."
        case .person:
            return "Tipp: Gezählt werden Filme, die du im aktuell gewählten Jahr gesehen hast – und in deren Cast diese Person vorkommt."
        }
    }

    private var canSave: Bool {
        switch initialGoal.type {
        case .decade:
            return target >= 1
        case .person:
            return target >= 1
            && selectedPersonId > 0
            && !selectedPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func buildUpdatedGoal() -> ViewingCustomGoal {
        switch initialGoal.type {
        case .decade:
            return ViewingCustomGoal(
                id: initialGoal.id,
                type: .decade,
                rule: .releaseDecade(decadeStart),
                target: max(1, target),
                createdAt: initialGoal.createdAt
            )
        case .person:
            return ViewingCustomGoal(
                id: initialGoal.id,
                type: .person,
                rule: .person(
                    id: selectedPersonId,
                    name: selectedPersonName.trimmingCharacters(in: .whitespacesAndNewlines),
                    profilePath: selectedProfilePath
                ),
                target: max(1, target),
                createdAt: initialGoal.createdAt
            )
        }
    }

    // MARK: - Search

    private func scheduleSearch(for raw: String) {
        searchTask?.cancel()

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            searchError = nil
            isSearching = false
            return
        }

        searchTask = Task {
            await MainActor.run {
                isSearching = true
                searchError = nil
            }

            // Debounce
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }

            do {
                let found = try await TMDbAPI.shared.searchPerson(name: trimmed)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.results = Array(found.prefix(20))
                    self.isSearching = false
                }
            } catch TMDbError.missingAPIKey {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.searchError = "TMDb API-Key fehlt. Bitte in TMDbAPI.swift eintragen."
                    self.isSearching = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.searchError = "Fehler bei der Personensuche."
                    self.isSearching = false
                }
            }
        }
    }

    @ViewBuilder
    private func avatar(profilePath: String?) -> some View {
        if let p = profilePath,
           let url = URL(string: "https://image.tmdb.org/t/p/w185\(p)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle().fill(Color.gray.opacity(0.2))
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Circle().fill(Color.gray.opacity(0.2))
                        .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                @unknown default:
                    Circle().fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            Circle().fill(Color.gray.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
        }
    }
}

#Preview {
    GoalsView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
}
