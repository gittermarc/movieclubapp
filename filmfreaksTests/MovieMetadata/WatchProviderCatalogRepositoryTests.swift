import Foundation
import Testing
@testable import filmfreaks

struct WatchProviderCatalogRepositoryTests {

    @Test func providerCatalogIsCachedByRegion() async throws {
        let base = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base) }
        let cache = TMDbMetadataCacheFileStore(baseDirectory: base)
        let probe = WatchProviderCatalogProbe()

        let firstRepository = WatchProviderCatalogRepository(
            dependencies: .init(
                fetchMovieWatchProviderCatalog: { region in
                    await probe.record(region: region)
                    return [Self.provider(id: 8, name: "Netflix")]
                },
                now: { Date(timeIntervalSince1970: 1_000) }
            ),
            cacheStore: cache
        )

        let first = try await firstRepository.providers(regionCode: "de")

        let secondRepository = WatchProviderCatalogRepository(
            dependencies: .init(
                fetchMovieWatchProviderCatalog: { region in
                    await probe.record(region: region)
                    return [Self.provider(id: 119, name: "Prime Video")]
                },
                now: { Date(timeIntervalSince1970: 1_500) }
            ),
            cacheStore: cache
        )

        let second = try await secondRepository.providers(regionCode: "DE")
        let calls = await probe.regions()

        #expect(calls == ["DE"])
        #expect(first.map(\.provider_id) == [8])
        #expect(second.map(\.provider_id) == [8])
    }

    private static func provider(id: Int, name: String) -> TMDbWatchProvider {
        TMDbWatchProvider(provider_id: id, provider_name: name, logo_path: nil, display_priority: id)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("watch-provider-catalog-tests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

actor WatchProviderCatalogProbe {
    private var recordedRegions: [String?] = []

    func record(region: String?) {
        recordedRegions.append(region)
    }

    func regions() -> [String?] {
        recordedRegions
    }
}
