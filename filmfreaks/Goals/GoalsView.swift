//
//  GoalsView.swift
//  filmfreaks
//
//  Jahresziel + Custom Goals (Decade / Actor / Director / Genre / Keyword)
//  Step 3+4: Goal Types als enum + generische Persistenz (1 Payload, 1 UI-Renderer)
//

internal import SwiftUI

// MARK: - GoalsView

@MainActor
struct GoalsView: View {

    @EnvironmentObject var movieStore: MovieStore

    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @StateObject var goalsStore = GoalsStore()

    // ✅ Custom Goals (v3+)
    @State var goalBeingEdited: ViewingCustomGoal? = nil
    @State var selectedGoalForDetail: ViewingCustomGoal? = nil

    // TMDb Genres (für Genre-Goals)
    @State var tmdbGenres: [TMDbGenre] = []
    @State var isLoadingGenres = false

    // Matching-Metadaten-Enrichment (optional, nur wenn Goals es brauchen)
    @State var isEnrichingMetadata = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    GoalsYearlyGoalCardView(
                        selectedYear: $selectedYear,
                        yearOptions: yearOptions(),
                        moviesInSelectedYear: moviesInSelectedYear,
                        yearlyTarget: yearlyTarget,
                        onSetYearlyTarget: setYearlyTarget,
                        yearlyProgress: yearlyProgress
                    )

                    GoalsCustomGoalsSectionView(
                        visibleGoals: sortedCustomGoals(),
                        allGoalsCount: goalsStore.customGoals.count,
                        selectedYear: selectedYear,
                        matchesProvider: { goal in
                            matchingMovies(for: goal)
                        },
                        onEdit: { goal in
                            goalBeingEdited = goal
                        },
                        onDelete: { goal in
                            deleteCustomGoal(goal)
                        },
                        onShowDetail: { goal in
                            selectedGoalForDetail = goal
                        }
                    )

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
}

// MARK: - Preview

#Preview {
    GoalsView()
        .environmentObject(MovieStore.preview())
        .environmentObject(DisplaySettings())
}
