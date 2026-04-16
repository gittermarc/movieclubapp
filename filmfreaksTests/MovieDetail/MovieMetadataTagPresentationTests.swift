import Testing
@testable import filmfreaks

struct MovieMetadataTagPresentationTests {

    @Test func normalizedNamesTrimRemoveEmptiesAndDeduplicatePreservingOrder() {
        let names = [
            "  Alien Contact  ",
            "",
            "First Contact",
            "alien contact",
            "   ",
            "Language",
            "First Contact"
        ]

        let normalized = MovieMetadataTagPresentation.normalizedNames(from: names)

        #expect(normalized == ["Alien Contact", "First Contact", "Language"])
    }
}
