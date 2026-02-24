//
//  CloudKitGroupStore+Subscriptions.swift
//  filmfreaks
//

import Foundation

extension CloudKitGroupStore {
    func ensureSubscriptions(forOwnedGroups owned: [GroupContext], forSharedGroups shared: [GroupContext]) async {
        await subscriptionManager.ensureSubscriptions(forOwnedGroups: owned)
        await subscriptionManager.ensureSubscriptions(forSharedGroups: shared)
    }
}
