import Foundation
import Testing
@testable import filmfreaks

struct GroupContextFixtureDecodingTests {

    @Test func privateGroupContextFixtureDecodes() throws {
        let context: GroupContext = try FixtureLoader.decode(
            GroupContext.self,
            named: "CloudRouting/group-context-private.json"
        )

        #expect(context.scope == .private)
        #expect(context.zoneName == "group-zone-private")
        #expect(context.ownerName == "__defaultOwner__")
        #expect(context.isShared == false)
    }

    @Test func sharedGroupContextFixtureDecodes() throws {
        let context: GroupContext = try FixtureLoader.decode(
            GroupContext.self,
            named: "CloudRouting/group-context-shared.json"
        )

        #expect(context.scope == .shared)
        #expect(context.zoneName == "group-zone-shared")
        #expect(context.ownerName == "_sharedOwner_")
        #expect(context.isShared)
    }
}
