import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieRouletteViewModelTests {

    @Test func updateResetsWinnerWhenGroupChanges() {
        let viewModel = MovieRouletteViewModel()
        let groupOneMovies = [makeMovie(title: "Heat", groupId: "group-1")]
        let groupTwoMovies = [makeMovie(title: "Arrival", groupId: "group-2")]

        viewModel.update(backlogMovies: groupOneMovies, currentGroupId: "group-1", currentGroupName: "Friday Crew", presets: [])
        viewModel.spin()
        viewModel.update(backlogMovies: groupTwoMovies, currentGroupId: "group-2", currentGroupName: "Sunday Crew", presets: [])

        #expect(viewModel.groupName == "Sunday Crew")
        #expect(viewModel.winningCandidate == nil)
        #expect(viewModel.candidates.map(\.title) == ["Arrival"])
    }

    @Test func updateWithoutActiveGroupProducesEmptyState() {
        let viewModel = MovieRouletteViewModel()

        viewModel.update(backlogMovies: [makeMovie(title: "Heat", groupId: "group-1")], currentGroupId: nil, currentGroupName: nil, presets: [])

        #expect(viewModel.candidates.isEmpty)
        #expect(viewModel.emptyStateTitle == "Keine Gruppe aktiv")
    }

    @Test func presetSourceUsesSelectedPresetMoviesInStoredOrder() {
        let viewModel = MovieRouletteViewModel()
        let preset = MovieRoulettePreset(
            groupId: "group-1",
            name: "Sci-Fi",
            sortIndex: 0,
            movieRefs: [
                MovieNightMovieRef(movieId: UUID(), title: "Arrival", year: "2016", posterPath: nil, tmdbId: nil),
                MovieNightMovieRef(movieId: UUID(), title: "Alien", year: "1979", posterPath: nil, tmdbId: nil)
            ]
        )

        viewModel.update(backlogMovies: [], currentGroupId: "group-1", currentGroupName: "Friday Crew", presets: [preset])
        viewModel.selectSource(.preset)

        #expect(viewModel.candidates.map(\.title) == ["Arrival", "Alien"])
        #expect(viewModel.sourceBadgeText == "Sci-Fi")
    }

    @Test func removingCandidateFromCurrentSessionShrinksPresetCandidates() {
        let viewModel = MovieRouletteViewModel()
        let firstId = UUID()
        let secondId = UUID()
        let preset = MovieRoulettePreset(
            groupId: "group-1",
            name: "Sci-Fi",
            sortIndex: 0,
            movieRefs: [
                MovieNightMovieRef(movieId: firstId, title: "Arrival", year: "2016", posterPath: nil, tmdbId: nil),
                MovieNightMovieRef(movieId: secondId, title: "Alien", year: "1979", posterPath: nil, tmdbId: nil)
            ]
        )

        viewModel.update(backlogMovies: [], currentGroupId: "group-1", currentGroupName: "Friday Crew", presets: [preset])
        viewModel.selectSource(.preset)

        let removed = viewModel.removeCandidateFromCurrentSession(candidateId: firstId)

        #expect(removed)
        #expect(viewModel.candidates.map(\.title) == ["Alien"])
        #expect(viewModel.winningCandidate == nil)
    }

    private func makeMovie(title: String, groupId: String?) -> Movie {
        var movie = Movie(title: title, year: "1995", addedAt: .now)
        movie.groupId = groupId
        return movie
    }
}
