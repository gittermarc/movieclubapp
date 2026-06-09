import Testing
@testable import filmfreaks

struct WatchProviderPreferencesPresentationTests {

    @Test func sortedCatalogDeduplicatesAndUsesDisplayPriorityThenName() {
        let providers = [
            provider(id: 2, name: "Zulu", priority: 10),
            provider(id: 1, name: "Beta", priority: 1),
            provider(id: 3, name: "Alpha", priority: 1),
            provider(id: 1, name: "Beta Duplicate", priority: 99)
        ]

        let sortedIDs = WatchProviderPreferencesPresentation.sortedCatalog(providers).map(\.provider_id)

        #expect(sortedIDs == [3, 1, 2])
    }

    @Test func filteredCatalogMatchesNameAndProviderID() {
        let providers = [
            provider(id: 8, name: "Netflix", priority: 1),
            provider(id: 119, name: "Prime Video", priority: 2)
        ]

        let byName = WatchProviderPreferencesPresentation.filteredCatalog(providers, query: "prime").map(\.provider_id)
        let byID = WatchProviderPreferencesPresentation.filteredCatalog(providers, query: "8").map(\.provider_id)

        #expect(byName == [119])
        #expect(byID == [8])
    }

    @Test func summaryUsesNamesWhenCatalogIsAvailable() {
        let providers = [
            provider(id: 8, name: "Netflix", priority: 1),
            provider(id: 119, name: "Prime Video", priority: 2),
            provider(id: 337, name: "Disney Plus", priority: 3),
            provider(id: 350, name: "Apple TV Plus", priority: 4)
        ]

        let summary = WatchProviderPreferencesPresentation.summaryText(
            selectedIDs: [8, 119, 337, 350],
            providers: providers
        )

        #expect(summary == "Netflix, Prime Video, Disney Plus +1")
    }

    private func provider(id: Int, name: String, priority: Int) -> TMDbWatchProvider {
        TMDbWatchProvider(provider_id: id, provider_name: name, logo_path: nil, display_priority: priority)
    }
}
