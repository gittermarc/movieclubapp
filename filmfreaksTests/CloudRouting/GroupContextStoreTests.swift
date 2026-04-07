import Foundation
import Testing
@testable import filmfreaks

struct GroupContextStoreTests {

    @Test func upsertLookupAllAndRemoveWorkWithIsolatedDefaults() throws {
        let defaultsSuite = try TestUserDefaultsSuite()
        let notificationCenter = NotificationCenter()

        let privateContext = GroupContext(
            id: "A0B1C2D3-E4F5-4A6B-8C7D-1234567890AB",
            name: "Movie Club",
            scope: .private,
            zoneName: "zone-private",
            ownerName: "__defaultOwner__"
        )
        let sharedContext = GroupContext(
            id: "B1C2D3E4-F5A6-4B7C-8D9E-ABCDEF123456",
            name: "Freitagsrunde",
            scope: .shared,
            zoneName: "zone-shared",
            ownerName: "_sharedOwner_"
        )

        GroupContextStore.upsert(privateContext, defaults: defaultsSuite.defaults, notificationCenter: notificationCenter)
        GroupContextStore.upsert(sharedContext, defaults: defaultsSuite.defaults, notificationCenter: notificationCenter)

        #expect(GroupContextStore.context(forGroupId: privateContext.id, defaults: defaultsSuite.defaults) == privateContext)
        #expect(Set(GroupContextStore.all(defaults: defaultsSuite.defaults).map(\.id)) == Set([privateContext.id, sharedContext.id]))

        GroupContextStore.remove(groupId: privateContext.id, defaults: defaultsSuite.defaults, notificationCenter: notificationCenter)

        #expect(GroupContextStore.context(forGroupId: privateContext.id, defaults: defaultsSuite.defaults) == nil)
        #expect(GroupContextStore.context(forGroupId: sharedContext.id, defaults: defaultsSuite.defaults) == sharedContext)
    }

    @Test func emptyGroupIdReturnsNil() throws {
        let defaultsSuite = try TestUserDefaultsSuite()
        #expect(GroupContextStore.context(forGroupId: "", defaults: defaultsSuite.defaults) == nil)
    }
}
