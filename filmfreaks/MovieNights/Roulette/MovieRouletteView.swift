//
//  MovieRouletteView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRouletteView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    @StateObject private var viewModel = MovieRouletteViewModel()
    @State private var isPresetManagerPresented: Bool = false
    @State private var proposalContext: ProposalContext?

    private var currentGroupId: String {
        (movieStore.currentGroupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentGroupPresets: [MovieRoulettePreset] {
        movieNightStore.roulettePresets(for: currentGroupId)
    }

    private var currentGroupBacklogMovies: [Movie] {
        MovieRouletteBacklogIndex(
            backlogMovies: movieStore.backlogMovies,
            activeGroupId: currentGroupId
        ).presetManagementMovies
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MovieRouletteHeaderCard(
                    viewModel: viewModel,
                    onManagePresets: presentPresetManager
                )

                MovieRouletteStageCard(viewModel: viewModel)

                MovieRouletteCandidatesCard(
                    viewModel: viewModel,
                    onManagePresets: presentPresetManager
                )

                if let winningCandidate = viewModel.winningCandidate {
                    MovieRouletteResultCard(
                        candidate: winningCandidate,
                        sourceTitle: viewModel.resultSourceTitle,
                        message: viewModel.resultMessage,
                        onSuggestMovieNight: {
                            proposalContext = ProposalContext(movieRef: winningCandidate.movieRef)
                        },
                        onSpinAgain: {
                            viewModel.spin()
                        },
                        onRemoveWinnerAndSpinAgain: removeWinnerAndSpinAgainAction
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: viewModel.winningCandidate?.id)
        .sensoryFeedback(.success, trigger: viewModel.winningCandidate?.id)
        .onAppear {
            syncFromStores()
            Task {
                await movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: false)
            }
        }
        .onReceive(movieStore.$backlogMovies) { _ in
            syncFromStores()
        }
        .onReceive(movieNightStore.$presetsByGroup) { _ in
            syncFromStores()
        }
        .onChange(of: movieStore.currentGroupId) { _, _ in
            syncFromStores()
        }
        .onChange(of: movieStore.currentGroupName) { _, _ in
            syncFromStores()
        }
        .sheet(item: $proposalContext) { proposalContext in
            ProposeMovieNightSheet(
                groupId: currentGroupId,
                initialDate: defaultProposedStart,
                initialSuggestedMovie: proposalContext.movieRef
            )
            .environmentObject(movieNightStore)
            .environmentObject(movieStore)
            .environmentObject(userStore)
            .environmentObject(displaySettings)
        }
        .sheet(isPresented: $isPresetManagerPresented) {
            MovieRoulettePresetManagementView(
                presets: currentGroupPresets,
                backlogMovies: currentGroupBacklogMovies,
                onCreatePreset: { name, movieRefs in
                    _ = movieNightStore.saveRoulettePreset(groupId: currentGroupId, name: name, movieRefs: movieRefs)
                    syncFromStores()
                },
                onUpdatePreset: { presetId, name, movieRefs in
                    _ = movieNightStore.saveRoulettePreset(groupId: currentGroupId, presetId: presetId, name: name, movieRefs: movieRefs)
                    viewModel.selectSource(.preset)
                    if let updatedPreset = movieNightStore.roulettePreset(for: currentGroupId, presetId: presetId) {
                        viewModel.selectPreset(updatedPreset.id)
                    }
                    syncFromStores()
                },
                onDeletePreset: { presetId in
                    movieNightStore.deleteRoulettePreset(groupId: currentGroupId, presetId: presetId)
                    syncFromStores()
                }
            )
            .environmentObject(displaySettings)
        }
    }

    private var defaultProposedStart: Date {
        Calendar.current.defaultMovieNightStart(for: .now)
    }

    private var removeWinnerAndSpinAgainAction: (() -> Void)? {
        guard viewModel.canRemoveWinnerAndSpinAgain else { return nil }
        return {
            viewModel.removeWinningCandidateAndSpinAgain()
        }
    }

    private func presentPresetManager() {
        isPresetManagerPresented = true
    }

    private func syncFromStores() {
        viewModel.update(
            backlogMovies: movieStore.backlogMovies,
            currentGroupId: movieStore.currentGroupId,
            currentGroupName: movieStore.currentGroupName,
            presets: currentGroupPresets
        )
    }

    private struct ProposalContext: Identifiable {
        let movieRef: MovieNightMovieRef

        var id: UUID { movieRef.movieId }
    }
}

#Preview {
    let movieStore = MovieStore.preview()
    movieStore.currentGroupId = "group-preview"
    movieStore.currentGroupName = "Friday Crew"
    movieStore.backlogMovies = [
        Movie(title: "The Big Lebowski", year: "1998", posterPath: nil, addedAt: .now, addedByName: "Marc"),
        Movie(title: "Arrival", year: "2016", posterPath: nil, addedAt: .now.addingTimeInterval(-3600), addedByName: "Marc"),
        Movie(title: "Heat", year: "1995", posterPath: nil, addedAt: .now.addingTimeInterval(-7200), addedByName: "Marc")
    ].map { movie in
        var copy = movie
        copy.groupId = "group-preview"
        copy.groupName = "Friday Crew"
        return copy
    }

    let movieNightStore = MovieNightStore(useCloud: false)
    movieNightStore.presetsByGroup["group-preview"] = [
        MovieRoulettePreset(
            groupId: "group-preview",
            name: "Sonntagsfilme",
            sortIndex: 0,
            movieRefs: movieStore.backlogMovies.prefix(2).map { MovieNightMovieRef(movie: $0) }
        )
    ]

    return NavigationStack {
        MovieRouletteView()
            .navigationTitle("Filmroulette")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(movieStore)
    .environmentObject(movieNightStore)
    .environmentObject(UserStore())
    .environmentObject(DisplaySettings())
}

private extension Calendar {
    func defaultMovieNightStart(for day: Date) -> Date {
        let base = startOfDay(for: day)
        if let candidate = date(bySettingHour: 20, minute: 0, second: 0, of: base) {
            return candidate
        }
        return day
    }
}
