import Foundation
import Testing
@testable import filmfreaks

struct MemberCloudDirtyJournalTests {

    @Test func avatarUpsertSurvivesJournalReload() throws {
        let temporaryDirectory = try TemporaryDirectory()
        let member = User(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Marc",
            avatarVersion: "avatar-v1"
        )
        let token = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let journal = MemberCloudDirtyJournal(rootURL: temporaryDirectory.url)

        journal.recordUpsert(
            member: member,
            groupId: "group-a",
            token: token,
            updatedAt: updatedAt
        )

        let reloaded = MemberCloudDirtyJournal(rootURL: temporaryDirectory.url)
        let entry = try #require(reloaded.entries(groupId: "group-a").first)

        #expect(entry.memberId == member.id)
        #expect(entry.operation == .upsert)
        #expect(entry.member == member)
        #expect(entry.token == token)
        #expect(entry.updatedAt == updatedAt)
    }

    @Test func deleteReplacesThePendingAvatarUpsertForTheSameMember() throws {
        let temporaryDirectory = try TemporaryDirectory()
        let member = User(name: "Michi", avatarVersion: "avatar-v1")
        let journal = MemberCloudDirtyJournal(rootURL: temporaryDirectory.url)

        journal.recordUpsert(member: member, groupId: "group-a")
        let deleteToken = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        journal.recordDelete(memberId: member.id, groupId: "group-a", token: deleteToken)

        let entry = try #require(journal.entries(groupId: "group-a").first)
        #expect(journal.entries(groupId: "group-a").count == 1)
        #expect(entry.operation == .delete)
        #expect(entry.member == nil)
        #expect(entry.token == deleteToken)
    }

    @Test func successfulFlushRemovalRequiresTheCurrentToken() throws {
        let temporaryDirectory = try TemporaryDirectory()
        let member = User(name: "Steffen", avatarVersion: "avatar-v1")
        let savedToken = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let newerToken = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let journal = MemberCloudDirtyJournal(rootURL: temporaryDirectory.url)

        journal.recordUpsert(member: member, groupId: "group-a", token: savedToken)
        journal.recordUpsert(member: member, groupId: "group-a", token: newerToken)
        journal.remove(memberId: member.id, matchingToken: savedToken, groupId: "group-a")

        let entry = try #require(journal.entries(groupId: "group-a").first)
        #expect(entry.token == newerToken)
        #expect(entry.member?.avatarVersion == "avatar-v1")
    }
}
