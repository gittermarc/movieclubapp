import Foundation
import Testing
@testable import filmfreaks

struct MemberAvatarStorageTests {

    @Test func avatarsAreStoredSeparatelyForEveryGroup() throws {
        let temporaryDirectory = try TemporaryDirectory()
        let storage = MemberAvatarStorage(rootURL: temporaryDirectory.url)
        let memberId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        try storage.storeAvatar(Data([0x01, 0x02]), memberId: memberId, groupId: "group-a")
        try storage.storeAvatar(Data([0x03, 0x04]), memberId: memberId, groupId: "group-b")

        #expect(storage.avatarData(memberId: memberId, groupId: "group-a") == Data([0x01, 0x02]))
        #expect(storage.avatarData(memberId: memberId, groupId: "group-b") == Data([0x03, 0x04]))
        #expect(storage.avatarURL(memberId: memberId, groupId: "group-a") != storage.avatarURL(memberId: memberId, groupId: "group-b"))
    }

    @Test func removingAvatarOnlyDeletesTheRequestedMemberImage() throws {
        let temporaryDirectory = try TemporaryDirectory()
        let storage = MemberAvatarStorage(rootURL: temporaryDirectory.url)
        let firstMemberId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondMemberId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        try storage.storeAvatar(Data([0x0A]), memberId: firstMemberId, groupId: "group-a")
        try storage.storeAvatar(Data([0x0B]), memberId: secondMemberId, groupId: "group-a")
        try storage.removeAvatar(memberId: firstMemberId, groupId: "group-a")

        #expect(storage.avatarData(memberId: firstMemberId, groupId: "group-a") == nil)
        #expect(storage.avatarData(memberId: secondMemberId, groupId: "group-a") == Data([0x0B]))
    }
}
