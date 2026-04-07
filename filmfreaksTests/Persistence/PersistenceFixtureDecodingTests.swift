import Foundation
import Testing
@testable import filmfreaks

struct PersistenceFixtureDecodingTests {

    @Test func emptyGroupFixturesDecodeAsEmptyMovieArrays() throws {
        let watched: [Movie] = try FixtureLoader.decode(
            [Movie].self,
            named: "Persistence/empty-group-watched-movies.json",
            using: TestFixtureDecoders.persistenceDecoder()
        )
        let backlog: [Movie] = try FixtureLoader.decode(
            [Movie].self,
            named: "Persistence/empty-group-backlog-movies.json",
            using: TestFixtureDecoders.persistenceDecoder()
        )

        #expect(watched.isEmpty)
        #expect(backlog.isEmpty)
    }

    @Test func usersAndKnownGroupsFixturesDecode() throws {
        let users: [User] = try FixtureLoader.decode(
            [User].self,
            named: "Persistence/small-group-users.json"
        )
        let groups: [GroupInfo] = try FixtureLoader.decode(
            [GroupInfo].self,
            named: "Persistence/known-groups.json"
        )

        #expect(users.count == 2)
        #expect(users.map(\.name) == ["Marc", "Michi"])
        #expect(groups.count == 2)
        #expect(groups.last?.displayName == "Movie Club")
    }

    @Test func watchedAndBacklogFixturesDecodeWithExpectedShape() throws {
        let watched: [Movie] = try FixtureLoader.decode(
            [Movie].self,
            named: "Persistence/watchlist-and-ratings-group-watched.json",
            using: TestFixtureDecoders.persistenceDecoder()
        )
        let backlog: [Movie] = try FixtureLoader.decode(
            [Movie].self,
            named: "Persistence/watchlist-and-ratings-group-backlog.json",
            using: TestFixtureDecoders.persistenceDecoder()
        )

        #expect(watched.count == 1)
        #expect(backlog.count == 2)
        #expect(watched.first?.ratings.count == 1)
        #expect(watched.first?.ratings.first?.fazitScore == 9)
        #expect(watched.first?.watchedLocation == "Nürnberg")
        #expect(backlog.allSatisfy { $0.watchedDate == nil })
    }
}
