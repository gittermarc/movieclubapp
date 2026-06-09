import Foundation
import Testing
@testable import filmfreaks

struct TMDbMetadataCacheKeyTests {

    @Test func metadataKeyDistinguishesMovieProfileAndRegion() {
        let germanDetail = TMDbMetadataCacheKey.metadata(movieID: 42, profile: .detailPage(regionCode: "de"))
        let usDetail = TMDbMetadataCacheKey.metadata(movieID: 42, profile: .detailPage(regionCode: "US"))
        let quickAdd = TMDbMetadataCacheKey.metadata(movieID: 42, profile: .quickAdd)
        let otherMovie = TMDbMetadataCacheKey.metadata(movieID: 43, profile: .detailPage(regionCode: "DE"))

        #expect(germanDetail != usDetail)
        #expect(germanDetail != quickAdd)
        #expect(germanDetail != otherMovie)
        #expect(germanDetail.regionCode == "DE")
    }

    @Test func fileNameIsStableAndFilesystemSafe() {
        let key = TMDbMetadataCacheKey.metadata(movieID: 42, profile: .detailPage(regionCode: "de"))

        #expect(key.fileName == "v1-metadata-movie-42-region-DE-profile-detailPage.json")
        #expect(!key.fileName.contains("|"))
        #expect(key.fileName.hasSuffix(".json"))
    }
}
