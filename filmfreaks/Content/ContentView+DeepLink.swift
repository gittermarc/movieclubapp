//
//  ContentView+DeepLink.swift
//  filmfreaks
//
//  Extracted from ContentView to isolate push deep-link handling.
//

internal import SwiftUI

extension ContentView {

    // MARK: - Push Deep Link (P2.4)

    func handlePushDeepLink(_ userInfo: [AnyHashable: Any]?) {
        guard
            let userInfo,
            let groupId = userInfo["groupId"] as? String
        else { return }

        let trimmed = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let ctx = GroupContextStore.context(forGroupId: trimmed) {
            if movieStore.currentGroupId != ctx.id {
                movieStore.activateCloudGroup(ctx)
            } else if movieStore.currentGroupName != ctx.name {
                movieStore.currentGroupName = ctx.name
            }
        } else if movieStore.currentGroupId != trimmed {
            movieStore.currentGroupId = trimmed
        }

        userStore.loadUsers(forGroupId: trimmed)

        Task {
            await groupStore.refresh()
            await movieStore.refreshFromCloud(force: true)
            await userStore.refreshFromCloud(force: true)
            await movieNightStore.refreshFromCloud(groupId: trimmed, force: true)
        }

        route = .activity
    }
}
