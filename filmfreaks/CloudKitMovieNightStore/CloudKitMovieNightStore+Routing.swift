//
//  CloudKitMovieNightStore+Routing.swift
//  filmfreaks
//
//  Split from CloudKitMovieNightStore.swift (P0.3)
//

import Foundation
import CloudKit

extension CloudKitMovieNightStore {

    enum RoutingError: LocalizedError {
        case groupContextNotReady(groupId: String)

        var errorDescription: String? {
            switch self {
            case .groupContextNotReady(let groupId):
                return "GroupContext not ready for groupId=\(groupId)"
            }
        }
    }

    /// Heuristik: groupId als UUID => sehr wahrscheinlich eine Sharing/Zone-Gruppe.
    /// In diesem Fall darf es **keinen** Fallback auf Public DB geben, sonst landen Records im falschen Scope.
    func requiresGroupContext(_ groupId: String) -> Bool {
        UUID(uuidString: groupId) != nil
    }

    func routedDatabase(forGroupId groupId: String) throws -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)

        if let ctx = GroupContextStore.context(forGroupId: gid) {
            let zoneID = CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)
            let db: CKDatabase = (ctx.scope == .shared) ? container.sharedCloudDatabase : container.privateCloudDatabase
            return (db, zoneID)
        }

        if requiresGroupContext(gid) {
            throw RoutingError.groupContextNotReady(groupId: gid)
        }

        // Legacy/public Gruppe (kein GroupContext): Public DB ohne Zone.
        return (container.publicCloudDatabase, nil)
    }
}
