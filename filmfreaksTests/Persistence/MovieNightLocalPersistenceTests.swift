import Foundation
import Testing
@testable import filmfreaks

struct MovieNightLocalPersistenceTests {

    @Test func saveAndLoadRoundTripPreservesSnapshotPayload() async throws {
        let tempDirectory = try TemporaryDirectory()
        let persistence = MovieNightLocalPersistence(baseDirectory: tempDirectory.url)
        let snapshot: MovieNightLocalPersistence.Snapshot = try FixtureLoader.decode(
            MovieNightLocalPersistence.Snapshot.self,
            named: "MovieNights/movie-night-snapshot-v2.json",
            using: TestFixtureDecoders.movieNightDecoder()
        )

        await persistence.save(snapshot)
        let loaded = await persistence.load()

        #expect(loaded.schemaVersion == snapshot.schemaVersion)
        #expect(loaded.eventsByGroup == snapshot.eventsByGroup)
        #expect(loaded.responsesByGroup == snapshot.responsesByGroup)
        #expect(loaded.activityByGroup == snapshot.activityByGroup)
        #expect(loaded.presetsByGroup.isEmpty)
    }

    @Test func corruptedSnapshotFileFallsBackToEmptySnapshot() async throws {
        let tempDirectory = try TemporaryDirectory()
        let persistence = MovieNightLocalPersistence(baseDirectory: tempDirectory.url)
        let fileURL = await persistence.fileURLForTesting()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try Data("{ invalid snapshot payload }".utf8).write(to: fileURL, options: [.atomic])

        let loaded = await persistence.load()

        #expect(loaded.schemaVersion == 3)
        #expect(loaded.eventsByGroup.isEmpty)
        #expect(loaded.responsesByGroup.isEmpty)
        #expect(loaded.activityByGroup.isEmpty)
        #expect(loaded.presetsByGroup.isEmpty)
    }

    @Test func saveAndLoadRoundTripPreservesPresetGroups() async throws {
        let tempDirectory = try TemporaryDirectory()
        let persistence = MovieNightLocalPersistence(baseDirectory: tempDirectory.url)
        let snapshot = MovieNightLocalPersistence.Snapshot(
            schemaVersion: 3,
            savedAt: .now,
            eventsByGroup: [:],
            responsesByGroup: [:],
            activityByGroup: [:],
            presetsByGroup: [
                "group-1": [
                    MovieRoulettePreset(
                        groupId: "group-1",
                        name: "Sci-Fi",
                        sortIndex: 0,
                        movieRefs: [MovieNightMovieRef(movieId: UUID(), title: "Arrival", year: "2016", posterPath: nil, tmdbId: nil)]
                    )
                ]
            ]
        )

        await persistence.save(snapshot)
        let loaded = await persistence.load()

        #expect(loaded.schemaVersion == 3)
        #expect(loaded.presetsByGroup == snapshot.presetsByGroup)
    }

    @Test func deleteLocalFileRemovesPersistedSnapshot() async throws {
        let tempDirectory = try TemporaryDirectory()
        let persistence = MovieNightLocalPersistence(baseDirectory: tempDirectory.url)
        let snapshot = MovieNightLocalPersistence.Snapshot.empty()

        await persistence.save(snapshot)
        let fileURL = await persistence.fileURLForTesting()
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        await persistence.deleteLocalFile()

        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }
}
