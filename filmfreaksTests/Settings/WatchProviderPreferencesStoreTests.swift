import Foundation
import Testing
@testable import filmfreaks

struct WatchProviderPreferencesStoreTests {

    @Test func preferencesAreStoredPerNormalizedRegion() throws {
        let suite = try TestUserDefaultsSuite(prefix: "watch-provider-preferences")
        let store = WatchProviderPreferencesStore(defaults: suite.defaults)

        store.setPreferredProviderIDs([8, 9], regionCode: "de")
        store.setPreferredProviderIDs([10], regionCode: "US")

        let germanIDs = store.preferredProviderIDs(regionCode: "DE")
        let usIDs = store.preferredProviderIDs(regionCode: "us")

        #expect(germanIDs == [8, 9])
        #expect(usIDs == [10])
    }

    @Test func toggleAddsAndRemovesProvider() throws {
        let suite = try TestUserDefaultsSuite(prefix: "watch-provider-toggle")
        let store = WatchProviderPreferencesStore(defaults: suite.defaults)

        let added = store.toggleProvider(8, regionCode: "de")
        let removed = store.toggleProvider(8, regionCode: "DE")

        #expect(added == [8])
        #expect(removed.isEmpty)
        #expect(store.preferredProviderIDs(regionCode: "DE").isEmpty)
    }

    @Test func clearOnlyRemovesCurrentRegion() throws {
        let suite = try TestUserDefaultsSuite(prefix: "watch-provider-clear")
        let store = WatchProviderPreferencesStore(defaults: suite.defaults)

        store.setPreferredProviderIDs([1, 2], regionCode: "DE")
        store.setPreferredProviderIDs([3], regionCode: "US")
        store.clear(regionCode: "de")

        #expect(store.preferredProviderIDs(regionCode: "DE").isEmpty)
        #expect(store.preferredProviderIDs(regionCode: "US") == [3])
    }

    @Test func storageKeyNormalizesRegion() {
        let lower = WatchProviderPreferencesStore.storageKey(for: "de")
        let upper = WatchProviderPreferencesStore.storageKey(for: "DE")

        #expect(lower == upper)
        #expect(lower.contains("DE"))
    }
}
