//
//  CloudKitRemoteNotificationDebugger.swift
//  filmfreaks
//
//  P2 (minimal): Receive CloudKit pushes and log what arrived.
//  Next step (P2 full) will map these notifications to local user-facing notifications.
//

import Foundation
import CloudKit

enum CloudKitRemoteNotificationDebugger {

    static func log(userInfo: [AnyHashable: Any]) {
        // Only print in debug builds to avoid noisy logs in production.
        #if DEBUG
        print("[Push] didReceiveRemoteNotification keys=\(userInfo.keys.map { "\($0)" }.sorted())")

        guard let ck = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("[Push] Not a CloudKit notification")
            return
        }

        switch ck.notificationType {
        case .query:
            log(query: ck)
        case .recordZone:
            log(recordZone: ck)
        case .database:
            log(database: ck)
        default:
            print("[Push] CloudKit notificationType=\(ck.notificationType.rawValue)")
        }
        #endif
    }

    // MARK: - Type logs

    private static func log(query ck: CKNotification) {
        guard let q = ck as? CKQueryNotification else {
            print("[Push] Expected CKQueryNotification, got \(type(of: ck))")
            return
        }

        let subscriptionID = q.subscriptionID ?? "(nil)"
        let recordName = q.recordID?.recordName ?? "(nil)"

        // Note: `CKQueryNotification` doesn't expose `recordType` on all OS versions / SDKs.
        // For P2 minimal we only log what is guaranteed: subscription + recordID.
        if let parsed = CloudKitActivitySubscriptionID.parse(subscriptionID) {
            print(
                "[Push] Query subscription=\(subscriptionID) groupId=\(parsed.groupId) kind=\(parsed.kind.rawValue) recordID=\(recordName)"
            )
        } else {
            print(
                "[Push] Query subscription=\(subscriptionID) recordID=\(recordName)"
            )
        }
    }

    private static func log(recordZone ck: CKNotification) {
        guard let z = ck as? CKRecordZoneNotification else {
            print("[Push] Expected CKRecordZoneNotification, got \(type(of: ck))")
            return
        }

        let subscriptionID = z.subscriptionID ?? "(nil)"
        let zoneName = z.recordZoneID?.zoneName ?? "(nil)"
        let ownerName = z.recordZoneID?.ownerName ?? "(nil)"

        print("[Push] RecordZone subscription=\(subscriptionID) zone=\(zoneName) owner=\(ownerName)")
    }

    private static func log(database ck: CKNotification) {
        guard let d = ck as? CKDatabaseNotification else {
            print("[Push] Expected CKDatabaseNotification, got \(type(of: ck))")
            return
        }

        let subscriptionID = d.subscriptionID ?? "(nil)"
        print("[Push] Database subscription=\(subscriptionID)")
    }
}

// MARK: - Activity subscription ID parsing

/// Subscription IDs are generated deterministically in `CloudKitActivitySubscriptionManager`:
/// `ff.act.<groupId>.<kind>`
struct CloudKitActivitySubscriptionID: Equatable {

    enum Kind: String {
        case movie
        case rating
        case movieNightActivity
    }

    let groupId: String
    let kind: Kind

    static func parse(_ subscriptionID: String) -> CloudKitActivitySubscriptionID? {
        // Fast-path check to avoid splitting for unrelated subscriptions.
        let prefix = "ff.act."
        guard subscriptionID.hasPrefix(prefix) else { return nil }

        let rest = String(subscriptionID.dropFirst(prefix.count))
        let parts = rest.split(separator: ".", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        // Kind is the last token; everything before it is the groupId (robust if groupId ever contains dots).
        guard let kind = Kind(rawValue: String(parts.last!)) else { return nil }
        let groupId = parts.dropLast().joined(separator: ".")
        guard !groupId.isEmpty else { return nil }
        return CloudKitActivitySubscriptionID(groupId: groupId, kind: kind)
    }
}
