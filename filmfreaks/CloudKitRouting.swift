//
//  CloudKitRouting.swift
//  filmfreaks
//
//  Centralized CloudKit DB + Zone routing with a safety guard:
//  UUID-like groupIds are treated as Sharing/Zone groups and must never fall back to Public DB.
//

import Foundation
import CloudKit

enum CloudKitRoutingError: LocalizedError, Equatable {
    case groupContextNotReady(groupId: String)

    var errorDescription: String? {
        switch self {
        case .groupContextNotReady(let groupId):
            return "GroupContext not ready for groupId=\(groupId)"
        }
    }
}

enum CloudKitRouting {

    /// Returns a trimmed, non-empty groupId or nil.
    static func normalizedGroupId(_ groupId: String?) -> String? {
        guard let groupId else { return nil }
        let trimmed = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Heuristic: UUID-like groupIds are treated as Sharing/Zone groups.
    /// For these, we must have a GroupContext; otherwise routing is unsafe.
    static func requiresGroupContext(for groupId: String) -> Bool {
        UUID(uuidString: groupId) != nil
    }

    /// Resolve DB + Zone for a groupId.
    ///
    /// - No groupId: Public DB.
    /// - GroupContext present: Private/Shared DB + Zone.
    /// - No GroupContext:
    ///     - UUID-like groupId: throw (must not fall back to Public DB)
    ///     - Otherwise: legacy/public group → Public DB.
    static func route(
        container: CKContainer,
        groupId: String?
    ) throws -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        guard let gid = normalizedGroupId(groupId) else {
            return (container.publicCloudDatabase, nil)
        }

        if let ctx = GroupContextStore.context(forGroupId: gid) {
            let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
            let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
            return (db, zoneID)
        }

        if requiresGroupContext(for: gid) {
            throw CloudKitRoutingError.groupContextNotReady(groupId: gid)
        }

        return (container.publicCloudDatabase, nil)
    }
}
