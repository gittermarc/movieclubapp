import Foundation
import Testing
@testable import filmfreaks

struct TestFoundationSmokeTests {

    @Test func fixturesRootExists() throws {
        #expect(FileManager.default.fileExists(atPath: FixtureLoader.fixturesRootURL.path))
    }

    @Test func requiredFixturesCanBeResolved() throws {
        let expectedFixtures = [
            "Persistence/empty-group-watched-movies.json",
            "Persistence/empty-group-backlog-movies.json",
            "Persistence/known-groups.json",
            "Persistence/small-group-users.json",
            "Persistence/watchlist-and-ratings-group-watched.json",
            "Persistence/watchlist-and-ratings-group-backlog.json",
            "Persistence/movie-legacy-cast.json",
            "CloudRouting/group-context-private.json",
            "CloudRouting/group-context-shared.json",
            "MovieNights/movie-night-snapshot-v1.json",
            "MovieNights/movie-night-snapshot-v2.json"
        ]

        for fixture in expectedFixtures {
            let url = try FixtureLoader.fixtureURL(named: fixture)
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }
}
