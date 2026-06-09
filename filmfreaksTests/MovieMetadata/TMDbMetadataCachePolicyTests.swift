import Foundation
import Testing
@testable import filmfreaks

struct TMDbMetadataCachePolicyTests {

    @Test func policiesUseExpectedFreshAndStaleWindows() {
        #expect(TMDbMetadataCachePolicy.movieDetails.freshDuration == 30 * 24 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.movieDetails.staleDuration == 90 * 24 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.collectionDetails.freshDuration == 30 * 24 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.recommendations.freshDuration == 24 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.recommendations.staleDuration == 7 * 24 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.watchProviders.freshDuration == 6 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.watchProviders.staleDuration == 24 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.negativeWatchProviders.freshDuration == 2 * 60 * 60)
        #expect(TMDbMetadataCachePolicy.negativeRecommendations.freshDuration == 6 * 60 * 60)
    }

    @Test func entryFreshnessMovesFromFreshToStaleToExpired() {
        let now = Date(timeIntervalSince1970: 1_000)
        let dates = TMDbMetadataCachePolicy.watchProviders.dates(now: now)
        let entry = TMDbMetadataCacheEntry(
            key: .watchProviders(movieID: 42, regionCode: "DE"),
            createdAt: now,
            expiresAt: dates.expiresAt,
            staleUntil: dates.staleUntil,
            payload: Data()
        )

        #expect(entry.freshness(now: now.addingTimeInterval(60)) == .fresh)
        #expect(entry.freshness(now: dates.expiresAt.addingTimeInterval(60)) == .stale)
        #expect(entry.freshness(now: dates.staleUntil.addingTimeInterval(60)) == .expired)
    }
}
