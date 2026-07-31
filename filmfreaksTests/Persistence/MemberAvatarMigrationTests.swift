import Foundation
import Testing
@testable import filmfreaks

struct MemberAvatarMigrationTests {

    @Test func legacyUsersFixtureDecodesWithoutAnAvatarVersion() throws {
        let users: [User] = try FixtureLoader.decode(
            [User].self,
            named: "Persistence/small-group-users.json"
        )

        #expect(users.allSatisfy { $0.avatarVersion == nil })
    }

    @Test func avatarVersionSurvivesUserRoundTrip() throws {
        let original = User(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Marc",
            avatarVersion: "avatar-v1"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(User.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.avatarVersion == "avatar-v1")
    }

    @Test func existingRatingsRemainIndependentOfMemberAvatars() throws {
        let watchedMovies: [Movie] = try FixtureLoader.decode(
            [Movie].self,
            named: "Persistence/watchlist-and-ratings-group-watched.json"
        )
        let rating = try #require(watchedMovies.first?.ratings.first)

        #expect(rating.reviewerId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(rating.reviewerName == "Marc")
    }
}
