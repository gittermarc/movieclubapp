import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieRouletteViewModelTests {

    @Test func updateResetsWinnerWhenGroupChanges() {
        let viewModel = MovieRouletteViewModel()
        let groupOneMovies = [makeMovie(title: "Heat", groupId: "group-1")]
        let groupTwoMovies = [makeMovie(title: "Arrival", groupId: "group-2")]

        viewModel.update(backlogMovies: groupOneMovies, currentGroupId: "group-1", currentGroupName: "Friday Crew")
        viewModel.spin()
        viewModel.update(backlogMovies: groupTwoMovies, currentGroupId: "group-2", currentGroupName: "Sunday Crew")

        #expect(viewModel.groupName == "Sunday Crew")
        #expect(viewModel.winningCandidate == nil)
        #expect(viewModel.candidates.map(\.title) == ["Arrival"])
    }

    @Test func updateWithoutActiveGroupProducesEmptyState() {
        let viewModel = MovieRouletteViewModel()

        viewModel.update(backlogMovies: [makeMovie(title: "Heat", groupId: "group-1")], currentGroupId: nil, currentGroupName: nil)

        #expect(viewModel.candidates.isEmpty)
        #expect(viewModel.emptyStateTitle == "Keine Gruppe aktiv")
    }

    private func makeMovie(title: String, groupId: String?) -> Movie {
        var movie = Movie(title: title, year: "1995", addedAt: .now)
        movie.groupId = groupId
        return movie
    }
}
