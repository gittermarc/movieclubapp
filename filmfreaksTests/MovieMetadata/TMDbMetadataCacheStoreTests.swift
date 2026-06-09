import Foundation
import Testing
@testable import filmfreaks

struct TMDbMetadataCacheStoreTests {

    @Test func readReturnsFreshAndStaleEntries() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let key = TMDbMetadataCacheKey.movieDetails(movieID: 42)
        let now = Date(timeIntervalSince1970: 1_000)

        await store.write(
            MovieMetadataTestFixtures.makeDetails(id: 42),
            for: key,
            policy: .movieDetails,
            now: now,
            isNegative: false
        )

        let freshRead = await store.read(TMDbMovieDetails.self, for: key, now: now.addingTimeInterval(60))
        let staleRead = await store.read(
            TMDbMovieDetails.self,
            for: key,
            now: now.addingTimeInterval(31 * 24 * 60 * 60)
        )

        #expect(freshRead?.freshness == .fresh)
        #expect(freshRead?.payload?.id == 42)
        #expect(staleRead?.freshness == .stale)
        #expect(staleRead?.payload?.id == 42)
    }

    @Test func negativeEntriesRoundTripWithoutPayload() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let key = TMDbMetadataCacheKey.watchProviders(movieID: 42, regionCode: "de")

        await store.write(
            Optional<TMDbWatchProvidersCountry>.none,
            for: key,
            policy: .negativeWatchProviders,
            now: Date(),
            isNegative: true
        )

        let read = await store.read(TMDbWatchProvidersCountry.self, for: key, now: Date())

        #expect(read?.entry.isNegative == true)
        #expect(read?.payload == nil)
        #expect(read?.freshness == .fresh)
    }

    @Test func corruptedCacheFileIsIgnoredAndRemoved() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let key = TMDbMetadataCacheKey.movieDetails(movieID: 42)
        let directory = base.appendingPathComponent("TMDbMetadata", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(key.fileName)
        try Data("kaputt".utf8).write(to: fileURL)

        let read = await store.read(TMDbMovieDetails.self, for: key, now: Date())

        #expect(read == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }


    @Test func cleanupCorruptedEntriesRemovesBrokenFiles() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let directory = base.appendingPathComponent("TMDbMetadata", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("broken.json")
        try Data("no json".utf8).write(to: fileURL)

        await store.cleanupCorruptedEntries()

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func cleanupAndRemoveAllManageFiles() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let store = TMDbMetadataCacheFileStore(baseDirectory: base)
        let key = TMDbMetadataCacheKey.movieDetails(movieID: 42)
        let now = Date(timeIntervalSince1970: 1_000)

        await store.write(
            MovieMetadataTestFixtures.makeDetails(id: 42),
            for: key,
            policy: .watchProviders,
            now: now,
            isNegative: false
        )

        let initialSize = await store.totalSizeInBytes()
        await store.cleanupExpiredEntries(now: now.addingTimeInterval(25 * 60 * 60))
        let afterCleanupSize = await store.totalSizeInBytes()
        await store.removeAll()
        let afterRemoveSize = await store.totalSizeInBytes()

        #expect(initialSize > 0)
        #expect(afterCleanupSize == 0)
        #expect(afterRemoveSize == 0)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tmdb-cache-tests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
