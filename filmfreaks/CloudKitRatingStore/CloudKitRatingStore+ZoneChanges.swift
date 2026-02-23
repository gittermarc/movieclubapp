//
//  CloudKitRatingStore+ZoneChanges.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

extension CloudKitRatingStore {

    // MARK: - Phase 2: Inkrementelle Zone-Changes (Sharing-Gruppen)

    struct RatingChanges {
        /// Alle geaenderten/neu hinzugekommenen Ratings (voll decodiert) gruppiert nach MovieId.
        let changedByMovieId: [UUID: [Rating]]
        /// Deletes kommen als (movieId, reviewerIdKey) zurueck.
        let deletedKeys: [(movieId: UUID, reviewerKey: String)]
        let isInitial: Bool
    }

    /// Holt Rating-Aenderungen fuer Sharing-Gruppen inkrementell.
    /// Fuer legacy/public (ohne Zone) gibt es ein leeres Delta zurueck.
    func fetchRatingChanges(forGroupId groupId: String?) async throws -> RatingChanges {
        guard let gid = groupId, !gid.isEmpty, let ctx = GroupContextStore.context(forGroupId: gid) else {
            return RatingChanges(changedByMovieId: [:], deletedKeys: [], isInitial: false)
        }

        let route = try routedDatabase(forGroupId: gid)
        guard let zoneID = route.zoneID else {
            return RatingChanges(changedByMovieId: [:], deletedKeys: [], isInitial: false)
        }

        let scope: CloudKitZoneChangeTokenStore.Scope = (ctx.scope == .shared) ? .shared : .private
        let namespace = "ratings"
        let previous = CloudKitZoneChangeTokenStore.token(namespace: namespace, scope: scope, zoneID: zoneID)

        let result = try await CloudKitZoneChanges.fetchAllChanges(database: route.db, zoneID: zoneID, previousToken: previous)
        CloudKitZoneChangeTokenStore.setToken(result.newChangeToken, namespace: namespace, scope: scope, zoneID: zoneID)

        // Decode changed ratings
        var changed: [UUID: [Rating]] = [:]
        for record in result.changedRecords where record.recordType == Schema.recordType {
            guard
                let movieIdString = record[Schema.movieIdKey] as? String,
                let movieUUID = UUID(uuidString: movieIdString),
                let data = record[Schema.payloadKey] as? Data
            else { continue }

            var rating = try JSONDecoder().decode(Rating.self, from: data)

            // Timestamp from the CloudKit record (authoritative).
            rating.updatedAt = record[Schema.updatedAtKey] as? Date

            if rating.reviewerId == nil {
                if let ridString = record[Schema.reviewerIdKey] as? String,
                   let rid = UUID(uuidString: ridString) {
                    rating.reviewerId = rid
                } else {
                    rating.reviewerId = StableID.deterministicUUID(forName: rating.reviewerName, groupId: gid)
                }
            }

            changed[movieUUID, default: []].append(rating)
        }

        // Normalize per movie (uniq)
        for (k, list) in changed {
            changed[k] = uniqByReviewer(list)
        }

        // Deletes: we need to infer (movieId, reviewerKey). We encode recordName as base64 of gid|movieId|reviewerId.
        // We can reconstruct movieId + reviewerId by decoding the base64.
        var deleted: [(movieId: UUID, reviewerKey: String)] = []
        for rid in result.deletedRecordIDs {
            guard result.deletedRecordTypesByID[rid] == Schema.recordType else { continue }
            if let parsed = parseRecordName(rid.recordName) {
                deleted.append((movieId: parsed.movieId, reviewerKey: parsed.reviewerKey))
            }
        }

        return RatingChanges(changedByMovieId: changed, deletedKeys: deleted, isInitial: (previous == nil))
    }
}
