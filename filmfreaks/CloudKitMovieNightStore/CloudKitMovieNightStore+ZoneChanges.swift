//
//  CloudKitMovieNightStore+ZoneChanges.swift
//  filmfreaks
//
//  Split from CloudKitMovieNightStore.swift (P0.3)
//

import Foundation
import CloudKit

extension CloudKitMovieNightStore {

    // MARK: - Zone changes (Sharing-Gruppen)

    struct MovieNightChanges {
        let changedEvents: [MovieNightEvent]
        let deletedEventIDs: [UUID]

        let changedResponses: [MovieNightResponse]
        /// composite response ids as defined by `MovieNightResponse.id`.
        let deletedResponseIDs: [String]

        let changedActivity: [MovieNightActivityEvent]
        let deletedActivityIDs: [UUID]

        let isInitial: Bool
    }

    /// Holt inkrementelle Aenderungen fuer Zone-basierte Gruppen.
    ///
    /// Fuer legacy/public groups (ohne GroupContext/Zone) wird ein leeres Delta zurueckgegeben.
    func fetchMovieNightChanges(forGroupId groupId: String) async throws -> MovieNightChanges {
        guard let ctx = GroupContextStore.context(forGroupId: groupId) else {
            return MovieNightChanges(
                changedEvents: [], deletedEventIDs: [],
                changedResponses: [], deletedResponseIDs: [],
                changedActivity: [], deletedActivityIDs: [],
                isInitial: false
            )
        }

        let route = try routedDatabase(forGroupId: groupId)
        guard let zoneID = route.zoneID else {
            return MovieNightChanges(
                changedEvents: [], deletedEventIDs: [],
                changedResponses: [], deletedResponseIDs: [],
                changedActivity: [], deletedActivityIDs: [],
                isInitial: false
            )
        }

        let scope: CloudKitZoneChangeTokenStore.Scope = (ctx.scope == .shared) ? .shared : .private
        let namespace = "movieNights"
        let previous = CloudKitZoneChangeTokenStore.token(namespace: namespace, scope: scope, zoneID: zoneID)

        let result = try await CloudKitZoneChanges.fetchAllChanges(database: route.db, zoneID: zoneID, previousToken: previous)
        CloudKitZoneChangeTokenStore.setToken(result.newChangeToken, namespace: namespace, scope: scope, zoneID: zoneID)

        var changedEvents: [MovieNightEvent] = []
        var changedResponses: [MovieNightResponse] = []
        var changedActivity: [MovieNightActivityEvent] = []

        changedEvents.reserveCapacity(16)
        changedResponses.reserveCapacity(16)
        changedActivity.reserveCapacity(16)

        for record in result.changedRecords {
            switch record.recordType {
            case eventRecordType:
                if let e = decodeEvent(record: record, fallbackGroupId: groupId) {
                    changedEvents.append(e)
                }
            case responseRecordType:
                if let r = decodeResponse(record: record) {
                    changedResponses.append(r)
                }
            case activityRecordType:
                if let a = decodeActivity(record: record, fallbackGroupId: groupId) {
                    changedActivity.append(a)
                }
            default:
                break
            }
        }

        var deletedEventIDs: [UUID] = []
        var deletedResponseIDs: [String] = []
        var deletedActivityIDs: [UUID] = []

        deletedEventIDs.reserveCapacity(8)
        deletedResponseIDs.reserveCapacity(8)
        deletedActivityIDs.reserveCapacity(8)

        for rid in result.deletedRecordIDs {
            guard let type = result.deletedRecordTypesByID[rid] else { continue }
            switch type {
            case eventRecordType:
                if let uuid = UUID(uuidString: rid.recordName) { deletedEventIDs.append(uuid) }
            case activityRecordType:
                if let uuid = UUID(uuidString: rid.recordName) { deletedActivityIDs.append(uuid) }
            case responseRecordType:
                if let parsed = parseResponseRecordName(rid.recordName) {
                    deletedResponseIDs.append(MovieNightResponse.compositeId(eventId: parsed.eventId, userId: parsed.userId))
                }
            default:
                break
            }
        }

        return MovieNightChanges(
            changedEvents: changedEvents,
            deletedEventIDs: deletedEventIDs,
            changedResponses: changedResponses,
            deletedResponseIDs: deletedResponseIDs,
            changedActivity: changedActivity,
            deletedActivityIDs: deletedActivityIDs,
            isInitial: (previous == nil)
        )
    }
}
