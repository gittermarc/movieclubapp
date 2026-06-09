import Testing
@testable import filmfreaks

struct MovieDiscoveryResultFilterTests {

    @Test func filterDeduplicatesAndRemovesKnownMovies() {
        let known = Movie(title: "Known", year: "2024", tmdbId: 1)
        let request = MovieDiscoveryRequest(
            existingWatched: [known],
            existingBacklog: [],
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: "DE",
            limitPerShelf: 10
        )

        let filtered = MovieDiscoveryResultFilter.filteredResults(
            [
                result(id: 1, title: "Known"),
                result(id: 2, title: "Fresh"),
                result(id: 2, title: "Fresh Duplicate"),
                result(id: 3, title: "Also Fresh")
            ],
            request: request
        )

        #expect(filtered.map(\.id) == [2, 3])
    }

    @Test func filterRespectsLimit() {
        let request = MovieDiscoveryRequest(
            existingWatched: [],
            existingBacklog: [],
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: "DE",
            limitPerShelf: 2
        )

        let filtered = MovieDiscoveryResultFilter.filteredResults(
            [
                result(id: 1, title: "One"),
                result(id: 2, title: "Two"),
                result(id: 3, title: "Three")
            ],
            request: request
        )

        #expect(filtered.map(\.id) == [1, 2])
    }

    private func result(id: Int, title: String) -> TMDbMovieResult {
        TMDbMovieResult(
            id: id,
            title: title,
            release_date: "2024-01-01",
            vote_average: 7.0,
            poster_path: nil
        )
    }
}
