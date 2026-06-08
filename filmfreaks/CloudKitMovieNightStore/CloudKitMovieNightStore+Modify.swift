//
//  CloudKitMovieNightStore+Modify.swift
//  filmfreaks
//
//  Split from CloudKitMovieNightStore.swift (P0.3)
//

import Foundation
import CloudKit

extension CloudKitMovieNightStore {

    // MARK: - Writes (Phase 4)

    /// Writes and deletes movie night records for a given group.
    ///
    /// - Important: This call is best-effort and may fail with transient CloudKit errors.
    ///   The caller is expected to retry (debounced upload queue).
    func modifyBatch(
        groupId: String,
        saveEvents: [MovieNightEvent],
        deleteEventIDs: [UUID],
        saveResponses: [MovieNightResponse],
        deleteResponses: [(eventId: UUID, userId: UUID)],
        saveActivity: [MovieNightActivityEvent],
        deleteActivityIDs: [UUID],
        savePresets: [MovieRoulettePreset],
        deletePresetIDs: [UUID]
    ) async throws {
        let gid = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gid.isEmpty else { return }

        let route = try routedDatabase(forGroupId: gid)

        var recordsToSave: [CKRecord] = []
        recordsToSave.reserveCapacity(saveEvents.count + saveResponses.count + saveActivity.count + savePresets.count)

        let rootRef: CKRecord.Reference? = {
            guard let zoneID = route.zoneID else { return nil }
            let rootID = CKRecord.ID(recordName: gid, zoneID: zoneID)
            return CKRecord.Reference(recordID: rootID, action: .none)
        }()


        let presetEncoder = JSONEncoder()

        // Events
        for e in saveEvents {
            let baseID = CKRecord.ID(recordName: e.id.uuidString)
            let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            let record = CKRecord(recordType: eventRecordType, recordID: id)
            record[groupIdKey] = gid as CKRecordValue
            record[proposedStartKey] = e.proposedStart as CKRecordValue
            record[createdAtKey] = e.createdAt as CKRecordValue
            record[updatedAtKey] = e.updatedAt as CKRecordValue
            record[proposerUserIdKey] = e.proposerUserId.uuidString as CKRecordValue
            record[proposerNameKey] = e.proposerName as CKRecordValue
            record[movieIdKey] = e.suggestedMovie?.movieId.uuidString as CKRecordValue?
            record[movieTitleKey] = e.suggestedMovie?.title as CKRecordValue?
            record[movieYearKey] = e.suggestedMovie?.year as CKRecordValue?
            record[moviePosterPathKey] = e.suggestedMovie?.posterPath as CKRecordValue?
            record[movieTmdbIdKey] = e.suggestedMovie?.tmdbId.map { NSNumber(value: $0) } as CKRecordValue?
            record[noteKey] = e.note as CKRecordValue?
            record[statusKey] = e.status.rawValue as CKRecordValue
            if let rootRef { record.parent = rootRef }
            recordsToSave.append(record)
        }

        // Responses
        for r in saveResponses {
            let recordName = responseRecordName(groupId: gid, eventId: r.eventId, userId: r.userId)
            let baseID = CKRecord.ID(recordName: recordName)
            let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            let record = CKRecord(recordType: responseRecordType, recordID: id)
            record[groupIdKey] = gid as CKRecordValue
            record[eventIdKey] = r.eventId.uuidString as CKRecordValue
            record[userIdKey] = r.userId.uuidString as CKRecordValue
            record[userNameKey] = r.userName as CKRecordValue
            record[decisionKey] = r.decision.rawValue as CKRecordValue
            record[respondedAtKey] = r.respondedAt as CKRecordValue
            if let rootRef { record.parent = rootRef }
            recordsToSave.append(record)
        }

        // Activity
        for a in saveActivity {
            let baseID = CKRecord.ID(recordName: a.id.uuidString)
            let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            let record = CKRecord(recordType: activityRecordType, recordID: id)
            record[groupIdKey] = gid as CKRecordValue
            record[kindKey] = a.kind.rawValue as CKRecordValue
            record[createdAtKey] = a.createdAt as CKRecordValue
            record[eventIdKey] = a.eventId.uuidString as CKRecordValue
            record[eventStartKey] = a.eventStart as CKRecordValue
            record[actorUserIdKey] = a.actorUserId.uuidString as CKRecordValue
            record[actorNameKey] = a.actorName as CKRecordValue
            record[decisionKey] = a.decision?.rawValue as CKRecordValue?
            record[newStatusKey] = a.newStatus?.rawValue as CKRecordValue?
            record[noteKey] = a.note as CKRecordValue?
            if let rootRef { record.parent = rootRef }
            recordsToSave.append(record)
        }

        // Presets
        for preset in savePresets {
            let baseID = CKRecord.ID(recordName: preset.id.uuidString)
            let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            let record = CKRecord(recordType: presetRecordType, recordID: id)
            record[groupIdKey] = gid as CKRecordValue
            record[presetNameKey] = preset.displayName as CKRecordValue
            record[sortIndexKey] = NSNumber(value: preset.sortIndex) as CKRecordValue
            record[updatedAtKey] = preset.updatedAt as CKRecordValue
            let data = try presetEncoder.encode(preset.movieRefs)
            let payload = String(data: data, encoding: .utf8) ?? "[]"
            record[presetMovieRefsKey] = payload as CKRecordValue
            if let rootRef { record.parent = rootRef }
            recordsToSave.append(record)
        }

        // Deletes
        var recordIDsToDelete: [CKRecord.ID] = []
        recordIDsToDelete.reserveCapacity(deleteEventIDs.count + deleteResponses.count + deleteActivityIDs.count + deletePresetIDs.count)

        for id in deleteEventIDs {
            let baseID = CKRecord.ID(recordName: id.uuidString)
            let rid = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            recordIDsToDelete.append(rid)
        }

        for d in deleteResponses {
            let name = responseRecordName(groupId: gid, eventId: d.eventId, userId: d.userId)
            let baseID = CKRecord.ID(recordName: name)
            let rid = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            recordIDsToDelete.append(rid)
        }

        for id in deleteActivityIDs {
            let baseID = CKRecord.ID(recordName: id.uuidString)
            let rid = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            recordIDsToDelete.append(rid)
        }

        for id in deletePresetIDs {
            let baseID = CKRecord.ID(recordName: id.uuidString)
            let rid = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
            recordIDsToDelete.append(rid)
        }

        let batches = MovieNightCloudKitModificationBatcher.modificationBatches(
            saves: recordsToSave,
            deletes: recordIDsToDelete
        )

        for batch in batches {
            try await movieNight_modifyRecords(database: route.db, saving: batch.saves, deleting: batch.deletes)
        }
    }
}

// MARK: - Internal helpers (CloudKit)

private func movieNight_modifyRecords(database: CKDatabase, saving: [CKRecord], deleting: [CKRecord.ID]) async throws {
    try await withCheckedThrowingContinuation { cont in
        let op = CKModifyRecordsOperation(recordsToSave: saving, recordIDsToDelete: deleting)
        op.savePolicy = .changedKeys
        op.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                cont.resume(returning: ())
            case .failure(let error):
                cont.resume(throwing: error)
            }
        }
        database.add(op)
    }
}
