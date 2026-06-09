import Testing
@testable import filmfreaks

struct MovieDiscoveryShelfTests {

    @Test func shelfKindsHaveStableTitles() {
        #expect(MovieDiscoveryShelfKind.personalizedRecommendations.title == "Für euch empfohlen")
        #expect(MovieDiscoveryShelfKind.preferredProviders.title == "Auf deinen Diensten")
        #expect(MovieDiscoveryShelfKind.trending.title == "Gerade angesagt")
        #expect(MovieDiscoveryShelfKind.topRated.title == "Top bewertet")
        #expect(MovieDiscoveryShelfKind.nowPlaying.title == "Neu im Kino")
        #expect(MovieDiscoveryShelfKind.popular.title == "Beliebt auf TMDb")
    }

    @Test func nowPlayingSubtitleIncludesRegion() {
        let subtitle = MovieDiscoveryShelfKind.nowPlaying.subtitle(regionCode: "DE", seedTitle: nil)
        #expect(subtitle?.contains("Deutschland") == true)
    }
}
