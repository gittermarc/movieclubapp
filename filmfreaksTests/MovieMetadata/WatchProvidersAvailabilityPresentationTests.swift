import Testing
@testable import filmfreaks

struct WatchProvidersAvailabilityPresentationTests {

    @Test func preferredProvidersAreSortedFirst() {
        let providers = [
            provider(id: 2, name: "Other", priority: 1),
            provider(id: 1, name: "Preferred", priority: 99),
            provider(id: 3, name: "Also Other", priority: 2)
        ]

        let sortedIDs = WatchProvidersAvailabilityPresentation.sortedDeduplicated(
            providers,
            preferredProviderIDs: [1]
        ).map(\.provider_id)

        #expect(sortedIDs == [1, 2, 3])
    }

    @Test func preferredSummaryOnlyAppearsWhenPreferredProviderIsAvailable() {
        let country = TMDbWatchProvidersCountry(
            link: nil,
            flatrate: [provider(id: 8, name: "Netflix", priority: 1)],
            ads: nil,
            free: nil,
            rent: [provider(id: 119, name: "Prime Video", priority: 2)],
            buy: nil
        )

        let available = WatchProvidersAvailabilityPresentation.preferredSummaryText(in: country, preferredProviderIDs: [119])
        let missing = WatchProvidersAvailabilityPresentation.preferredSummaryText(in: country, preferredProviderIDs: [337])

        #expect(available == "Deine Anbieter verfügbar: Prime Video")
        #expect(missing == nil)
    }

    private func provider(id: Int, name: String, priority: Int) -> TMDbWatchProvider {
        TMDbWatchProvider(provider_id: id, provider_name: name, logo_path: nil, display_priority: priority)
    }
}
