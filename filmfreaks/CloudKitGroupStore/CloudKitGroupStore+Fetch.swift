//
//  CloudKitGroupStore+Fetch.swift
//  filmfreaks
//

import Foundation
import CloudKit

extension CloudKitGroupStore {

    /// IMPORTANT:
    /// We intentionally DO NOT query for FFGroup records.
    /// Some CloudKit environments throw "recordName is not queryable" for queries.
    ///
    /// Our design guarantees:
    /// - Zone name: "group.<GROUP_ID>"
    /// - Root record name: "<GROUP_ID>" inside that zone
    ///
    /// So we list zones and directly fetch the root record by ID.
    func fetchGroupContexts(in db: CKDatabase, scope: GroupScope) async throws -> [GroupContext] {
        let zones = try await fetchAllZones(in: db)
        let groupZones = zones.filter { $0.zoneID.zoneName.hasPrefix("group.") }

        var contexts: [GroupContext] = []
        contexts.reserveCapacity(groupZones.count)

        for zone in groupZones {
            let zoneName = zone.zoneID.zoneName
            guard let groupId = parseGroupId(fromZoneName: zoneName) else { continue }

            let rootID = CKRecord.ID(recordName: groupId, zoneID: zone.zoneID)

            do {
                let record = try await db.record(for: rootID)
                let name = (record[Self.nameKey] as? String) ?? "Filmgruppe"
                let ownerName = record.recordID.zoneID.ownerName

                contexts.append(
                    GroupContext(
                        id: groupId,
                        name: name,
                        scope: scope,
                        zoneName: zoneName,
                        ownerName: ownerName
                    )
                )
            } catch {
                // If the zone exists but the root record was deleted or not created yet, ignore it.
                // (This can happen in edge cases during migration or partial writes.)
                print("CloudKitGroupStore: Could not fetch root record for zone \(zoneName): \(error)")
                continue
            }
        }

        return contexts
    }

    func createZoneIfNeeded(zoneID: CKRecordZone.ID) async throws -> CKRecordZone {
        do {
            let zone = CKRecordZone(zoneID: zoneID)
            return try await privateDB.save(zone)
        } catch {
            // Zone creation is idempotent for our purposes.
            return CKRecordZone(zoneID: zoneID)
        }
    }

    func deleteRecordZone(in db: CKDatabase, zoneID: CKRecordZone.ID) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.delete(withRecordZoneID: zoneID) { _, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    func parseGroupId(fromZoneName zoneName: String) -> String? {
        let prefix = "group."
        guard zoneName.hasPrefix(prefix) else { return nil }
        let id = String(zoneName.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }
}

// MARK: - CloudKit async helpers (completion -> async)

private func fetchAllZones(in db: CKDatabase) async throws -> [CKRecordZone] {
    try await withCheckedThrowingContinuation { cont in
        db.fetchAllRecordZones { zones, error in
            if let error {
                cont.resume(throwing: error)
            } else {
                cont.resume(returning: zones ?? [])
            }
        }
    }
}
