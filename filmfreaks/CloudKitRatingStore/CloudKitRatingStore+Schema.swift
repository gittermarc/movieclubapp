//
//  CloudKitRatingStore+Schema.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

extension CloudKitRatingStore {

    // MARK: - Schema

    enum Schema {
        static let recordType = "MovieRating"

        static let payloadKey = "payload"              // Data: codierter Rating
        static let movieIdKey = "movieId"              // String: UUID
        static let groupIdKey = "groupId"              // String: Group-ID
        static let reviewerIdKey = "reviewerId"        // String: UUID (stabile Identität)
        static let reviewerNameKey = "reviewerName"    // String: Display-Name (optional, Debug/Stats)
        static let updatedAtKey = "updatedAt"          // Date
    }

    // MARK: - Helpers

    func normalizedGroupId(_ groupId: String?) -> String {
        (groupId?.isEmpty == false) ? groupId! : "nogroup"
    }

    func stableReviewerId(for rating: Rating, groupId: String?) -> UUID {
        if let rid = rating.reviewerId { return rid }
        guard let gid = groupId, !gid.isEmpty else {
            // Offline/no-group: best-effort deterministic based on name only is not stable on rename,
            // but offline groups are local anyway.
            return UUID()
        }
        return StableID.deterministicUUID(forName: rating.reviewerName, groupId: gid)
    }

    func recordID(groupId: String?, movieId: UUID, reviewerId: UUID) -> CKRecord.ID {
        // Stabil & safe: base64-url of "gid|movieId|reviewerId"
        let gid = normalizedGroupId(groupId)
        let raw = gid + "|" + movieId.uuidString + "|" + reviewerId.uuidString.lowercased()
        let data = raw.data(using: .utf8) ?? Data()
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "+", with: "-")
        b64 = b64.replacingOccurrences(of: "/", with: "_")
        b64 = b64.replacingOccurrences(of: "=", with: "")
        return CKRecord.ID(recordName: b64)
    }

    /// Parsed content of our stable recordName encoding.
    struct ParsedRecordName {
        let movieId: UUID
        let reviewerKey: String
    }

    func parseRecordName(_ recordName: String) -> ParsedRecordName? {
        // We store a base64-url string of: "gid|movieId|reviewerId"
        var b64 = recordName
        b64 = b64.replacingOccurrences(of: "-", with: "+")
        b64 = b64.replacingOccurrences(of: "_", with: "/")
        // pad
        let mod = b64.count % 4
        if mod != 0 {
            b64 += String(repeating: "=", count: 4 - mod)
        }
        guard let data = Data(base64Encoded: b64),
              let raw = String(data: data, encoding: .utf8)
        else { return nil }

        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let movie = String(parts[1])
        let reviewer = String(parts[2])
        guard let movieId = UUID(uuidString: movie) else { return nil }
        // We use reviewerId if possible, else fall back to raw reviewer token.
        if let reviewerId = UUID(uuidString: reviewer) {
            return ParsedRecordName(movieId: movieId, reviewerKey: reviewerId.uuidString.lowercased())
        }
        return ParsedRecordName(movieId: movieId, reviewerKey: reviewer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func reviewerKey(_ r: Rating) -> String {
        if let id = r.reviewerId { return id.uuidString.lowercased() }
        return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func uniqByReviewer(_ ratings: [Rating]) -> [Rating] {
        var result: [Rating] = []
        var seen: Set<String> = []

        for r in ratings {
            let key = reviewerKey(r)
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(r)
        }
        return result
    }

    func merge(dictA: [UUID: [Rating]], dictB: [UUID: [Rating]]) -> [UUID: [Rating]] {
        var merged = dictA
        for (movieId, ratings) in dictB {
            merged[movieId] = mergeRatings(existing: merged[movieId] ?? [], incoming: ratings)
        }
        return merged
    }

    func mergeRatings(existing: [Rating], incoming: [Rating]) -> [Rating] {
        var out = existing
        for r in incoming {
            let key = reviewerKey(r)
            if let idx = out.firstIndex(where: { reviewerKey($0) == key }) {
                out[idx] = r
            } else {
                out.append(r)
            }
        }
        return out
    }
}
