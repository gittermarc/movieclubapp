//
//  CloudKitMovieStore+ZoneChanges.swift
//  filmfreaks
//
//  Split out: incremental zone changes (sharing groups).
//

import Foundation
import CloudKit

extension CloudKitMovieStore {

    // MARK: - Phase 2: Inkrementelle Zone-Changes (Sharing-Gruppen)

    struct MovieChanges {
        let changed: [CloudMovieEntry]
        let deletedMovieIDs: [UUID]
        /// true wenn `previousToken == nil` (also ein "voller" Initial-Fetch innerhalb der Zone).
        let isInitial: Bool
    }

    /// Holt Aenderungen fuer Sharing-Gruppen inkrementell via `CKFetchRecordZoneChangesOperation`.
    ///
    /// - For legacy/public groups (ohne Zone) wird ein leerer Delta-Container zurueckgegeben.
    ///   (In diesen Faellen bleibt der bestehende Query-Pfad aktiv.)
    func fetchMovieChanges(forGroupId groupId: String?) async throws -> MovieChanges {
        guard let gid = groupId, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
            return MovieChanges(changed: [], deletedMovieIDs: [], isInitial: false)
        }

        let route = try routedDatabase(forGroupId: gid)
        guard let zoneID = route.zoneID else {
            return MovieChanges(changed: [], deletedMovieIDs: [], isInitial: false)
        }

        let scope: CloudKitZoneChangeTokenStore.Scope = (ctx.scope == .shared) ? .shared : .private
        let namespace = "movies"
        let previous = CloudKitZoneChangeTokenStore.token(namespace: namespace, scope: scope, zoneID: zoneID)

        let fetchResult = try await CloudKitTokenRecovery.fetchZoneChangesWithSingleRecovery(
            database: route.db,
            zoneID: zoneID,
            previousToken: previous,
            clearToken: {
                CloudKitZoneChangeTokenStore.clear(namespace: namespace, scope: scope, zoneID: zoneID)
            }
        )
        let result = fetchResult.changes

        // Persist new token (even if nil; best-effort)
        CloudKitZoneChangeTokenStore.setToken(result.newChangeToken, namespace: namespace, scope: scope, zoneID: zoneID)

        // Decode only Movie records
        var changed: [CloudMovieEntry] = []
        changed.reserveCapacity(result.changedRecords.count)
        for record in result.changedRecords where record.recordType == recordType {
            if let entry = try decodeMovie(from: record) {
                changed.append(entry)
            }
        }

        // Only deletes for Movie type
        var deleted: [UUID] = []
        deleted.reserveCapacity(result.deletedRecordIDs.count)
        for rid in result.deletedRecordIDs {
            guard result.deletedRecordTypesByID[rid] == recordType else { continue }
            if let uuid = UUID(uuidString: rid.recordName) {
                deleted.append(uuid)
            }
        }

        return MovieChanges(changed: changed, deletedMovieIDs: deleted, isInitial: !fetchResult.usedPreviousToken)
    }
}
