import Foundation
import Testing
@testable import filmfreaks

struct SettingsCacheSizeCalculatorTests {

    @Test func totalLocalCacheBytesIncludesImageAndTMDbMetadataCaches() throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let imageDirectory = base.appendingPathComponent("ImageCacheStore", isDirectory: true)
        let metadataDirectory = base.appendingPathComponent("TMDbMetadata", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 12).write(to: imageDirectory.appendingPathComponent("cover.img"))
        try Data(repeating: 2, count: 8).write(to: metadataDirectory.appendingPathComponent("metadata.json"))

        let calculator = SettingsCacheSizeCalculator(cachesDirectory: base)

        #expect(calculator.imageCacheBytes() == 12)
        #expect(calculator.tmdbMetadataCacheBytes() == 8)
        #expect(calculator.totalLocalCacheBytes() == 20)
    }

    @Test func totalLocalCacheBytesIgnoresMissingDirectories() throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let calculator = SettingsCacheSizeCalculator(cachesDirectory: base)

        #expect(calculator.totalLocalCacheBytes() == 0)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings-cache-size-tests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
