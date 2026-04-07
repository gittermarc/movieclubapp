import CloudKit
import Foundation
import Testing
@testable import filmfreaks

struct CloudKitZoneChangeTokenStoreTests {

    @Test func setTokenNilClearsPersistedValue() throws {
        let defaultsSuite = try TestUserDefaultsSuite()
        let zoneID = CKRecordZone.ID(zoneName: "movie-zone", ownerName: "__defaultOwner__")
        let key = CloudKitZoneChangeTokenStore.tokenKey(namespace: "movies", scope: .private, zoneID: zoneID)

        defaultsSuite.defaults.set(Data("placeholder".utf8), forKey: key)
        CloudKitZoneChangeTokenStore.setToken(nil, namespace: "movies", scope: .private, zoneID: zoneID, defaults: defaultsSuite.defaults)

        #expect(defaultsSuite.defaults.object(forKey: key) == nil)
        #expect(CloudKitZoneChangeTokenStore.token(namespace: "movies", scope: .private, zoneID: zoneID, defaults: defaultsSuite.defaults) == nil)
    }

    @Test func corruptedPersistedTokenIsDiscarded() throws {
        let defaultsSuite = try TestUserDefaultsSuite()
        let zoneID = CKRecordZone.ID(zoneName: "ratings-zone", ownerName: "_sharedOwner_")
        let key = CloudKitZoneChangeTokenStore.tokenKey(namespace: "ratings", scope: .shared, zoneID: zoneID)

        defaultsSuite.defaults.set(Data("not-a-valid-token".utf8), forKey: key)

        let token = CloudKitZoneChangeTokenStore.token(namespace: "ratings", scope: .shared, zoneID: zoneID, defaults: defaultsSuite.defaults)

        #expect(token == nil)
        #expect(defaultsSuite.defaults.object(forKey: key) == nil)
    }
}
