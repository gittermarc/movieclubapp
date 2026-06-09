import Testing
@testable import filmfreaks

struct MovieDiscoveryMembershipResolverTests {

    @Test func membershipPrefersTMDbID() {
        let result = TMDbMovieResult(
            id: 42,
            title: "Different Title",
            release_date: "2024-01-01",
            vote_average: 7.0,
            poster_path: nil
        )
        let watched = [Movie(title: "Stored Title", year: "2024", tmdbId: 42)]

        let isKnown = MovieDiscoveryMembershipResolver.isKnown(
            result,
            watched: watched,
            backlog: [],
            localWatchedKeys: [],
            localBacklogKeys: []
        )

        #expect(isKnown)
    }

    @Test func membershipFallsBackToTitleAndYear() {
        let result = TMDbMovieResult(
            id: 100,
            title: "Fallback Film",
            release_date: "2024-04-01",
            vote_average: 7.0,
            poster_path: nil
        )
        let backlog = [Movie(title: "Fallback Film", year: "2024", tmdbId: nil)]

        let isKnown = MovieDiscoveryMembershipResolver.isKnown(
            result,
            watched: [],
            backlog: backlog,
            localWatchedKeys: [],
            localBacklogKeys: []
        )

        #expect(isKnown)
    }
}
