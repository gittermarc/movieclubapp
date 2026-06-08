import Foundation
import Testing
@testable import filmfreaks

struct GroupScopedStorageTests {

    @Test func groupDirectoryUsesStableSafeGroupFolderNames() throws {
        let tempDirectory = try TemporaryDirectory()

        let first = GroupScopedStorage.groupDirectoryURL(root: tempDirectory.url, groupId: "group-a")
        let second = GroupScopedStorage.groupDirectoryURL(root: tempDirectory.url, groupId: "group-a")
        let other = GroupScopedStorage.groupDirectoryURL(root: tempDirectory.url, groupId: "group-b")
        let local = GroupScopedStorage.groupDirectoryURL(root: tempDirectory.url, groupId: nil)

        #expect(first == second)
        #expect(first != other)
        #expect(local.lastPathComponent == "default")
        #expect(first.path.hasSuffix("groups/group-a"))
    }

    @Test func groupJSONFileURLBuildsExpectedGroupScopedPath() throws {
        let tempDirectory = try TemporaryDirectory()

        let url = GroupScopedStorage.groupJSONFileURL(
            root: tempDirectory.url,
            groupId: "movie club / friday",
            fileName: "movies_watched.json"
        )

        #expect(url.lastPathComponent == "movies_watched.json")
        #expect(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent == "groups")
        #expect(url.deletingLastPathComponent().lastPathComponent.contains("/") == false)
    }

    @Test func movieNightSnapshotURLPreservesLegacyLowercaseFolder() throws {
        let tempDirectory = try TemporaryDirectory()

        let url = GroupScopedStorage.movieNightSnapshotURL(baseDirectory: tempDirectory.url)

        #expect(url.lastPathComponent == "movieNights.json")
        #expect(url.deletingLastPathComponent().lastPathComponent == "filmfreaks")
    }

    @Test func userDefaultsKeysRemainStable() {
        #expect(GroupScopedStorage.UserDefaultsKey.currentGroupId == "CurrentGroupId")
        #expect(GroupScopedStorage.UserDefaultsKey.currentGroupName == "CurrentGroupName")
        #expect(GroupScopedStorage.UserDefaultsKey.knownGroups == "KnownGroups")
        #expect(GroupScopedStorage.UserDefaultsKey.yearlyGoals == "ViewingGoalsByYear.v1")
        #expect(GroupScopedStorage.UserDefaultsKey.customGoals(groupId: nil) == "ViewingCustomGoals.v3.")
        #expect(GroupScopedStorage.UserDefaultsKey.customGoals(groupId: "group-a") == "ViewingCustomGoals.v3.group-a")
    }

    @Test func syncMetaKeysAreGroupScopedAndStable() {
        #expect(
            GroupScopedStorage.UserDefaultsKey.movieStoreSyncMeta(groupId: nil, suffix: "pendingCount") ==
            "MovieStore.SyncMeta.__default__.pendingCount"
        )
        #expect(
            GroupScopedStorage.UserDefaultsKey.movieStoreSyncMeta(groupId: " group-a ", suffix: "lastError") ==
            "MovieStore.SyncMeta.group-a.lastError"
        )
        #expect(
            GroupScopedStorage.UserDefaultsKey.movieNightSyncMeta(groupId: "group-a", suffix: "pending") ==
            "MovieNightStore.SyncMeta.group-a.pending"
        )
    }

    @Test func selectedUserGroupKeyKeepsLocalSelectionSeparate() {
        #expect(GroupScopedStorage.selectedUserGroupKey(for: nil) == "__local__")
        #expect(GroupScopedStorage.selectedUserGroupKey(for: "") == "__local__")
        #expect(GroupScopedStorage.selectedUserGroupKey(for: " group-a ") == "group-a")
    }
}
