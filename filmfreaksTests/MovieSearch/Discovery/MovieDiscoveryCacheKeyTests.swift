import Foundation
import Testing
@testable import filmfreaks

struct MovieDiscoveryCacheKeyTests {

    @Test func nowPlayingKeyIncludesNormalizedRegion() {
        let key = MovieDiscoveryCacheKey.cacheKey(
            kind: .nowPlaying,
            request: request(regionCode: "de")
        )

        #expect(key.namespace == "discovery")
        #expect(key.profileName == MovieDiscoveryShelfKind.nowPlaying.rawValue)
        #expect(key.regionCode == "DE")
    }

    @Test func personalizedKeyIncludesSeedIDs() {
        let watched = [
            Movie(title: "Seed One", year: "2020", watchedDate: Date(timeIntervalSince1970: 200), tmdbId: 42),
            Movie(title: "Seed Two", year: "2021", watchedDate: Date(timeIntervalSince1970: 100), tmdbId: 84)
        ]
        let key = MovieDiscoveryCacheKey.cacheKey(
            kind: .personalizedRecommendations,
            request: request(existingWatched: watched)
        )

        #expect(key.variant?.hasPrefix("seeds-") == true)
        #expect(key.variant?.contains("42") == true)
        #expect(key.variant?.contains("84") == true)
    }

    private func request(existingWatched: [Movie] = [], regionCode: String? = "DE") -> MovieDiscoveryRequest {
        MovieDiscoveryRequest(
            existingWatched: existingWatched,
            existingBacklog: [],
            localWatchedKeys: [],
            localBacklogKeys: [],
            regionCode: regionCode
        )
    }
}
