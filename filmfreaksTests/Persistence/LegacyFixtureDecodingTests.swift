import Foundation
import Testing
@testable import filmfreaks

struct LegacyFixtureDecodingTests {

    @Test func legacyMovieCastFixtureMigratesNamesIntoCastMembers() throws {
        let movie: Movie = try FixtureLoader.decode(
            Movie.self,
            named: "Persistence/movie-legacy-cast.json",
            using: TestFixtureDecoders.persistenceDecoder()
        )

        let cast = try #require(movie.cast)

        #expect(cast.count == 3)
        #expect(cast.map(\.name) == ["Keanu Reeves", "Carrie-Anne Moss", "Laurence Fishburne"])
        #expect(cast.allSatisfy { $0.personId < 0 })
    }

    @Test func movieNightSnapshotV1FixtureDecodesWithoutActivityStream() throws {
        let snapshot: MovieNightLocalPersistence.Snapshot = try FixtureLoader.decode(
            MovieNightLocalPersistence.Snapshot.self,
            named: "MovieNights/movie-night-snapshot-v1.json",
            using: TestFixtureDecoders.movieNightDecoder()
        )

        #expect(snapshot.schemaVersion == 1)
        #expect(snapshot.eventsByGroup.count == 1)
        #expect(snapshot.responsesByGroup.count == 1)
        #expect(snapshot.activityByGroup.isEmpty)
        #expect(snapshot.presetsByGroup.isEmpty)
    }

    @Test func movieNightSnapshotV2FixtureDecodesActivityStream() throws {
        let snapshot: MovieNightLocalPersistence.Snapshot = try FixtureLoader.decode(
            MovieNightLocalPersistence.Snapshot.self,
            named: "MovieNights/movie-night-snapshot-v2.json",
            using: TestFixtureDecoders.movieNightDecoder()
        )

        #expect(snapshot.schemaVersion == 2)
        #expect(snapshot.activityByGroup.count == 1)
        #expect(snapshot.activityByGroup.values.flatMap { $0 }.first?.newStatus == .scheduled)
        #expect(snapshot.presetsByGroup.isEmpty)
    }
}
