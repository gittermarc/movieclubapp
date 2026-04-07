import CloudKit
import Foundation
import Testing
@testable import filmfreaks

struct CloudKitRoutingTests {

    @Test func normalizedGroupIdTrimsAndRejectsBlankValues() {
        #expect(CloudKitRouting.normalizedGroupId(nil) == nil)
        #expect(CloudKitRouting.normalizedGroupId("   \n  ") == nil)
        #expect(CloudKitRouting.normalizedGroupId("  abc-123  ") == "abc-123")
    }

    @Test func uuidLikeGroupIdsRequireGroupContext() {
        #expect(CloudKitRouting.requiresGroupContext(for: "A0B1C2D3-E4F5-4A6B-8C7D-1234567890AB"))
        #expect(CloudKitRouting.requiresGroupContext(for: "legacy-public-code") == false)
    }

    @Test func nilGroupRoutesToPublicDatabase() throws {
        let container = CKContainer(identifier: "iCloud.com.example.filmfreaks.tests")
        let route = try CloudKitRouting.route(container: container, groupId: nil)

        #expect(ObjectIdentifier(route.db) == ObjectIdentifier(container.publicCloudDatabase))
        #expect(route.zoneID == nil)
    }

    @Test func legacyGroupWithoutContextRoutesToPublicDatabase() throws {
        let container = CKContainer(identifier: "iCloud.com.example.filmfreaks.tests")
        let route = try CloudKitRouting.route(container: container, groupId: "legacy-public-code") { _ in nil }

        #expect(ObjectIdentifier(route.db) == ObjectIdentifier(container.publicCloudDatabase))
        #expect(route.zoneID == nil)
    }

    @Test func uuidGroupWithoutContextThrows() throws {
        let container = CKContainer(identifier: "iCloud.com.example.filmfreaks.tests")

        #expect(throws: CloudKitRoutingError.groupContextNotReady(groupId: "A0B1C2D3-E4F5-4A6B-8C7D-1234567890AB")) {
            try CloudKitRouting.route(
                container: container,
                groupId: "A0B1C2D3-E4F5-4A6B-8C7D-1234567890AB",
                contextLookup: { _ in nil }
            )
        }
    }

    @Test func privateContextRoutesToPrivateDatabaseAndZone() throws {
        let container = CKContainer(identifier: "iCloud.com.example.filmfreaks.tests")
        let context = GroupContext(
            id: "A0B1C2D3-E4F5-4A6B-8C7D-1234567890AB",
            name: "Movie Club",
            scope: .private,
            zoneName: "zone-private",
            ownerName: "__defaultOwner__"
        )

        let route = try CloudKitRouting.route(container: container, groupId: context.id) { _ in context }

        #expect(ObjectIdentifier(route.db) == ObjectIdentifier(container.privateCloudDatabase))
        #expect(route.zoneID == CKRecordZone.ID(zoneName: "zone-private", ownerName: "__defaultOwner__"))
    }

    @Test func sharedContextRoutesToSharedDatabaseAndZone() throws {
        let container = CKContainer(identifier: "iCloud.com.example.filmfreaks.tests")
        let context = GroupContext(
            id: "B1C2D3E4-F5A6-4B7C-8D9E-ABCDEF123456",
            name: "Freitagsrunde",
            scope: .shared,
            zoneName: "zone-shared",
            ownerName: "_sharedOwner_"
        )

        let route = try CloudKitRouting.route(container: container, groupId: context.id) { _ in context }

        #expect(ObjectIdentifier(route.db) == ObjectIdentifier(container.sharedCloudDatabase))
        #expect(route.zoneID == CKRecordZone.ID(zoneName: "zone-shared", ownerName: "_sharedOwner_"))
    }
}
