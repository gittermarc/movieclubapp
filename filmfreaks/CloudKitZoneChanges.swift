//
//  CloudKitZoneChanges.swift
//  filmfreaks
//
//  Phase 2 (Skalierung): Inkrementelles Laden per Zone Changes.
//

import Foundation
import CloudKit

/// Ergebnis eines Zone-Changes Fetches.
struct CloudKitZoneChangesResult {
    var changedRecords: [CKRecord]
    var deletedRecordIDs: [CKRecord.ID]
    /// recordID -> recordType (nur fuer Deletes relevant)
    var deletedRecordTypesByID: [CKRecord.ID: String]
    var newChangeToken: CKServerChangeToken?
}

/// Wrapper um `CKFetchRecordZoneChangesOperation` fuer async/await.
enum CloudKitZoneChanges {

    /// Holt alle Aenderungen seit `previousToken` fuer genau eine Zone.
    ///
    /// - Important: Diese Operation liefert *nur* Records innerhalb der Zone.
    ///   In eurer Sharing-Architektur ist eine Zone = eine Gruppe -> perfekt.
    static func fetchAllChanges(
        database: CKDatabase,
        zoneID: CKRecordZone.ID,
        previousToken: CKServerChangeToken?
    ) async throws -> CloudKitZoneChangesResult {

        try await withCheckedThrowingContinuation { cont in
            var changed: [CKRecord] = []
            var deletedIDs: [CKRecord.ID] = []
            var deletedTypes: [CKRecord.ID: String] = [:]

            var finalZoneToken: CKServerChangeToken?
            var zoneSpecificError: Error?

            var config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = previousToken
            config.desiredKeys = nil

            let op = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            op.fetchAllChanges = true

            op.recordChangedBlock = { record in
                changed.append(record)
            }

            op.recordWithIDWasDeletedBlock = { recordID, recordType in
                deletedIDs.append(recordID)
                deletedTypes[recordID] = recordType
            }

            // Best-effort token updates waehrend Paging/Teil-Erfolgen
            op.recordZoneChangeTokensUpdatedBlock = { updatedZoneID, token, _ in
                guard updatedZoneID == zoneID else { return }
                if let token { finalZoneToken = token }
            }

            // ✅ Moderne API: pro Zone kommt ein Result mit serverChangeToken etc.
            op.recordZoneFetchResultBlock = { fetchedZoneID, result in
                guard fetchedZoneID == zoneID else { return }
                switch result {
                case .success(let info):
                    // info: (serverChangeToken: CKServerChangeToken, clientChangeTokenData: Data?, moreComing: Bool)
                    finalZoneToken = info.serverChangeToken
                case .failure(let error):
                    zoneSpecificError = error
                }
            }

            // ✅ Moderne API: Gesamt-Result ist Result<Void, Error>
            op.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    if let zoneSpecificError {
                        cont.resume(throwing: zoneSpecificError)
                        return
                    }
                    cont.resume(returning: CloudKitZoneChangesResult(
                        changedRecords: changed,
                        deletedRecordIDs: deletedIDs,
                        deletedRecordTypesByID: deletedTypes,
                        newChangeToken: finalZoneToken
                    ))
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }

            database.add(op)
        }
    }
}
