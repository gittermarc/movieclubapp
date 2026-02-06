//
//  GoalsView.swift
//  filmfreaks
//
//  Jahresziel + Custom Goals (Decade / Actor / Director / Genre / Keyword)
//  Step 3+4: Goal Types als enum + generische Persistenz (1 Payload, 1 UI-Renderer)
//

internal import SwiftUI

// MARK: - GoalsView

struct GoalsView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var displaySettings: DisplaySettings

    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State var goalsByYear: [Int: Int] = [:]

    // ✅ Custom Goals (v3+)
    @State var customGoals: [ViewingCustomGoal] = []
    @State var goalBeingEdited: ViewingCustomGoal? = nil
    @State var selectedGoalForDetail: ViewingCustomGoal? = nil

    // TMDb Genres (für Genre-Goals)
    @State var tmdbGenres: [TMDbGenre] = []
    @State var isLoadingGenres = false

    // Matching-Metadaten-Enrichment (optional, nur wenn Goals es brauchen)
    @State var isEnrichingMetadata = false

    // Sync handling (für Jahresziele + Custom Goals)
    @State var syncCount: Int = 0
    var isSyncingGoals: Bool { syncCount > 0 }

    let yearlyGoalsStorageKey = "ViewingGoalsByYear.v1"
    let defaultYearlyGoal = 50

    var customGoalsStorageKey: String {
        let gid = movieStore.currentGroupId ?? ""
        return "ViewingCustomGoals.v3.\(gid)"
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
                                target: 10,
                                startYear: selectedYear,
                                durationYears: 1
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
                    contextYear: selectedYear,
                    availableYears: Array(Set(yearOptions() + [goal.startYear])).sorted(by: >),
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
                            moviePosterNavTile(for: m)
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
        let visibleGoals = sortedCustomGoals()
        let otherYearsCount = max(0, customGoals.count - visibleGoals.count)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Custom Goals")
                    .font(.headline)
                Spacer()
                Text("\(visibleGoals.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
            }

            if visibleGoals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "In \(selectedYear) sind noch keine Custom Goals angelegt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if otherYearsCount > 0 {
                        Text("Du hast \(otherYearsCount) Ziel(e) in anderen Jahren – die siehst du, wenn du oben das Jahr wechselst.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Beispiele: „10 Filme aus den 50ern“, „15 Filme von Nolan“, „8 Filme mit time travel“.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(visibleGoals) { goal in
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

                    Text(goal.validityLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

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
                            moviePosterNavTile(for: m)
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
                .background(displaySettings.tint(0.14))
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
                CachedAsyncImage(url: url) { phase in
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
    private func moviePosterNavTile(for movie: Movie) -> some View {
        if let idx = movieStore.movies.firstIndex(where: { $0.id == movie.id }) {
            NavigationLink {
                MovieDetailView(
                    movie: $movieStore.movies[idx],
                    isBacklog: false
                )
            } label: {
                posterTile(for: movie)
            }
            .buttonStyle(.plain)
        } else {
            posterTile(for: movie)
        }
    }

    @ViewBuilder
    private func goalLeadingView(_ goal: ViewingCustomGoal) -> some View {
        switch goal.type {
        case .decade:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(displaySettings.tintSoftBackground)
                Image(systemName: ViewingCustomGoalType.decade.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            .frame(width: 44, height: 44)

        case .person, .director:
            if let path = goal.profilePath, !path.isEmpty,
               let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
                CachedAsyncImage(url: url) { phase in
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
                        .fill(displaySettings.tintSoftBackground)
                    Image(systemName: goal.type == .director ? ViewingCustomGoalType.director.systemImage : ViewingCustomGoalType.person.systemImage)
                        .foregroundStyle(.tint)
                }
                .frame(width: 44, height: 44)
            }

        case .genre:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(displaySettings.tintSoftBackground)
                Image(systemName: ViewingCustomGoalType.genre.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            .frame(width: 44, height: 44)

        case .keyword:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(displaySettings.tintSoftBackground)
                Image(systemName: ViewingCustomGoalType.keyword.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            .frame(width: 44, height: 44)
        }
    }

}

// MARK: - Preview

#Preview {
    GoalsView()
        .environmentObject(MovieStore.preview())
        .environmentObject(DisplaySettings())
}
