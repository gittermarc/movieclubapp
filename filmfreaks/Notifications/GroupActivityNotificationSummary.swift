//
//  GroupActivityNotificationSummary.swift
//  filmfreaks
//
//  P2 (full): Minimal activity summary used to build a local notification.
//

import Foundation

struct GroupActivityNotificationSummary: Equatable {

    enum Kind: String {
        case movie
        case rating
        case movieNightActivity
    }

    let kind: Kind
    let groupId: String
    let groupName: String

    /// CloudKit recordName
    let recordID: String

    /// Best-effort actor identity.
    let actorName: String?
    let actorId: UUID?

    /// Notification UI
    let title: String
    let body: String

    /// Payload for future deep links.
    let userInfo: [String: String]
}
