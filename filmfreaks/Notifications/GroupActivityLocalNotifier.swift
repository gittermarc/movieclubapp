//
//  GroupActivityLocalNotifier.swift
//  filmfreaks
//
//  P2 (full): Convert fetched CloudKit activity into a local user notification.
//  Includes dedupe + best-effort own-action suppression.
//

import Foundation
import UserNotifications

@MainActor
final class GroupActivityLocalNotifier {

    static let shared = GroupActivityLocalNotifier()

    private let state = ActivityNotificationStateStore.shared

    private init() {}

    func maybeNotify(_ summary: GroupActivityNotificationSummary) async {
        // 1) Dedupe
        guard state.shouldNotify(groupId: summary.groupId, recordID: summary.recordID) else {
            #if DEBUG
            print("[Push] 🔕 skip notify (dedupe) groupId=\(summary.groupId) recordID=\(summary.recordID)")
            #endif
            return
        }

        // 2) Skip own actions (best effort)
        if isOwnAction(summary) {
            #if DEBUG
            print("[Push] 🔕 skip notify (own action) groupId=\(summary.groupId) recordID=\(summary.recordID)")
            #endif
            // still mark as handled so we don't notify later for the same record
            state.markNotified(groupId: summary.groupId, recordID: summary.recordID)
            return
        }

        // 3) Must be authorized for alerts (or provisional)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            #if DEBUG
            print("[Push] 🔕 skip notify (not authorized) status=\(settings.authorizationStatus.rawValue)")
            #endif
            return
        }

        let content = UNMutableNotificationContent()
        content.title = summary.title
        content.body = summary.body
        content.sound = .default
        content.userInfo = summary.userInfo

        let identifier = "ff.act.\(summary.groupId).\(summary.recordID)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            try await center.add(request)
            state.markNotified(groupId: summary.groupId, recordID: summary.recordID)
            #if DEBUG
            print("[Push] 🔔 notified \(summary.kind.rawValue) groupId=\(summary.groupId) recordID=\(summary.recordID)")
            #endif
        } catch {
            #if DEBUG
            print("[Push] 🔕 notify failed error=\(error)")
            #endif
        }
    }

    private func isOwnAction(_ summary: GroupActivityNotificationSummary) -> Bool {
        if let currentId = CurrentUserIdentityStore.currentUserId(),
           let actorId = summary.actorId,
           currentId == actorId {
            return true
        }

        if let currentName = CurrentUserIdentityStore.currentUserName(),
           let actorName = summary.actorName,
           !currentName.isEmpty,
           currentName.caseInsensitiveCompare(actorName) == .orderedSame {
            return true
        }

        return false
    }
}
