//
//  PushDeepLinkRouter.swift
//  filmfreaks
//
//  P2.4: Deep link routing when the user taps a push notification.
//  We support two payload shapes:
//  1) Local notifications we create ourselves (userInfo contains "groupId"/"kind").
//  2) CloudKit system notifications (derive groupId/kind from subscriptionID).
//

import Foundation
import CloudKit

@MainActor
enum PushDeepLinkRouter {

    struct DeepLink: Equatable {
        let groupId: String
        let kind: String?
        let openActivity: Bool
    }

    static func route(userInfo: [AnyHashable: Any]) {
        guard let link = parse(userInfo: userInfo) else { return }
        NotificationCenter.default.post(
            name: .pushDeepLinkRequested,
            object: nil,
            userInfo: [
                "groupId": link.groupId,
                "kind": link.kind ?? "",
                "openActivity": link.openActivity
            ]
        )
    }

    private static func parse(userInfo: [AnyHashable: Any]) -> DeepLink? {
        // 1) Our local notifications (best path).
        if let groupId = userInfo["groupId"] as? String {
            let trimmed = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let kind = (userInfo["kind"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return DeepLink(groupId: trimmed, kind: kind, openActivity: true)
        }

        // 2) CloudKit system notification: derive via subscriptionID.
        guard let ck = CKNotification(fromRemoteNotificationDictionary: userInfo) else { return nil }
        guard let subscriptionID = (ck as? CKQueryNotification)?.subscriptionID ?? ck.subscriptionID else { return nil }
        guard let parsed = CloudKitActivitySubscriptionID.parse(subscriptionID) else { return nil }
        return DeepLink(groupId: parsed.groupId, kind: parsed.kind.rawValue, openActivity: true)
    }
}
