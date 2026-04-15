import Testing
@testable import filmfreaks

struct GroupSettingsPresentationTests {

    @Test func activeGroupBadgeShowsLocalWithoutCloudGroup() {
        let badge = GroupSettingsPresentation.activeGroupBadgeText(
            currentGroupId: nil,
            activeContext: nil
        )

        #expect(badge == "Lokal")
    }

    @Test func activeGroupBadgeShowsCloudWhenContextIsNotLoadedYet() {
        let badge = GroupSettingsPresentation.activeGroupBadgeText(
            currentGroupId: "group-1",
            activeContext: nil
        )

        #expect(badge == "Cloud")
    }

    @Test func activeGroupBadgeUsesGermanLabelsForOwnedAndSharedGroups() {
        let ownedContext = GroupContext(
            id: "owned",
            name: "Owned Group",
            scope: .private,
            zoneName: "zone-owned",
            ownerName: "owner"
        )
        let sharedContext = GroupContext(
            id: "shared",
            name: "Shared Group",
            scope: .shared,
            zoneName: "zone-shared",
            ownerName: "owner"
        )

        #expect(GroupSettingsPresentation.activeGroupBadgeText(currentGroupId: ownedContext.id, activeContext: ownedContext) == "Eigene Gruppe")
        #expect(GroupSettingsPresentation.activeGroupBadgeText(currentGroupId: sharedContext.id, activeContext: sharedContext) == "Geteilte Gruppe")
    }

    @Test func activeGroupSummaryUsesExpectedCountCopy() {
        let summary = GroupSettingsPresentation.activeGroupSummary(
            memberCount: 1,
            watchedCount: 2,
            backlogCount: 3
        )

        #expect(summary == "1 Mitglied • 2 Filme • 3 im Backlog")
    }

    @Test func pendingActionUsesExpectedTitleAndMessageCopy() {
        let group = GroupContext(
            id: "group-1",
            name: "Sci-Fi",
            scope: .private,
            zoneName: "zone-1",
            ownerName: "owner"
        )

        let deleteAction = GroupSettingsPendingAction(kind: .deleteOwned, group: group)
        let leaveAction = GroupSettingsPendingAction(kind: .leaveShared, group: group)

        #expect(deleteAction.title == "Gruppe löschen?")
        #expect(deleteAction.message.contains("Sci-Fi"))
        #expect(deleteAction.message.contains("endgültig gelöscht"))

        #expect(leaveAction.title == "Gruppe verlassen?")
        #expect(leaveAction.message.contains("Sci-Fi"))
        #expect(leaveAction.message.contains("per Einladung"))
    }
}
