//
//  CloudKitRatingStore+Modify.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

extension CloudKitRatingStore {

    // MARK: - Save / Delete

    // MARK: - Phase 2: Batched Saves (Migration / Initial Upload)

    /// Speichert viele Ratings in einem oder mehreren `CKModifyRecordsOperation` Batches.
    /// Wird v.a. bei Legacy-Migration genutzt.
    func saveRatingsBatch(
        _ items: [(rating: Rating, movieId: UUID)],
        groupId: String?
    ) async throws {
        guard !items.isEmpty else { return }

        let route = try routedDatabase(forGroupId: groupId)
        let reviewerIds: [UUID] = items.map { stableReviewerId(for: $0.rating, groupId: groupId) }

        let maxPerOp = 200
        var start = 0

        while start < items.count {
            let end = min(items.count, start + maxPerOp)
            let slice = Array(items[start..<end])

            var records: [CKRecord] = []
            records.reserveCapacity(slice.count)

            for (idx, item) in slice.enumerated() {
                let reviewerId = reviewerIds[start + idx]
                let baseID = recordID(groupId: groupId, movieId: item.movieId, reviewerId: reviewerId)
                let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID

                var ratingToEncode = item.rating
                if ratingToEncode.reviewerId == nil { ratingToEncode.reviewerId = reviewerId }

                let now = Date()
                ratingToEncode.updatedAt = now

                let record = CKRecord(recordType: Schema.recordType, recordID: id)
                let data = try JSONEncoder().encode(ratingToEncode)
                record[Schema.payloadKey] = data as CKRecordValue
                record[Schema.movieIdKey] = item.movieId.uuidString as CKRecordValue
                record[Schema.groupIdKey] = (groupId?.isEmpty == false) ? (groupId! as CKRecordValue) : nil
                record[Schema.reviewerIdKey] = reviewerId.uuidString.lowercased() as CKRecordValue
                record[Schema.reviewerNameKey] = ratingToEncode.reviewerName as CKRecordValue
                record[Schema.updatedAtKey] = now as CKRecordValue

                records.append(record)
            }

            try await modifyRecords(database: route.db, saving: records, deleting: [])
            start = end
        }
    }

    func saveRating(_ rating: Rating, movieId: UUID, groupId: String?) async throws {
        let route = try routedDatabase(forGroupId: groupId)
        let reviewerId = stableReviewerId(for: rating, groupId: groupId)

        let baseID = recordID(groupId: groupId, movieId: movieId, reviewerId: reviewerId)
        let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID

        func applyFields(on record: CKRecord) throws -> CKRecord {
            var ratingToEncode = rating
            if ratingToEncode.reviewerId == nil {
                ratingToEncode.reviewerId = reviewerId
            }

            let now = Date()
            ratingToEncode.updatedAt = now

            let data = try JSONEncoder().encode(ratingToEncode)
            record[Schema.payloadKey] = data as CKRecordValue
            record[Schema.movieIdKey] = movieId.uuidString as CKRecordValue
            record[Schema.groupIdKey] = (groupId?.isEmpty == false) ? (groupId! as CKRecordValue) : nil

            // CloudKit Sharing (record sharing):
            // Ensure the rating record is a descendant of the shared group root record.
            if let gid = groupId, !gid.isEmpty, let zoneID = route.zoneID {
                let rootID = CKRecord.ID(recordName: gid, zoneID: zoneID)
                record.parent = CKRecord.Reference(recordID: rootID, action: .none)
            } else {
                record.parent = nil
            }

            record[Schema.reviewerIdKey] = reviewerId.uuidString.lowercased() as CKRecordValue
            record[Schema.reviewerNameKey] = ratingToEncode.reviewerName as CKRecordValue
            record[Schema.updatedAtKey] = now as CKRecordValue
            return record
        }

        do {
            let base: CKRecord
            do {
                base = try await route.db.record(for: id)
            } catch {
                base = CKRecord(recordType: Schema.recordType, recordID: id)
            }

            let recordToSave = try applyFields(on: base)
            _ = try await route.db.save(recordToSave)

        } catch {
            // Konflikte sind selten (ein Record pro Reviewer), aber wir behandeln sie robust.
            if let ckError = error as? CKError,
               ckError.code == .serverRecordChanged,
               let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                let updated = try applyFields(on: serverRecord)
                _ = try await route.db.save(updated)
                return
            }
            throw error
        }
    }

    func deleteRating(movieId: UUID, groupId: String?, reviewerId: UUID) async throws {
        let route = try routedDatabase(forGroupId: groupId)
        let baseID = recordID(groupId: groupId, movieId: movieId, reviewerId: reviewerId)
        let id = route.zoneID.map { CKRecord.ID(recordName: baseID.recordName, zoneID: $0) } ?? baseID
        _ = try await route.db.deleteRecord(withID: id)
    }
}

// MARK: - Internal helpers (Phase 2)

private func modifyRecords(database: CKDatabase, saving: [CKRecord], deleting: [CKRecord.ID]) async throws {
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
