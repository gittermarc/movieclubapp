//
//  CloudKitMovieNightStore+Schema.swift
//  filmfreaks
//
//  Split from CloudKitMovieNightStore.swift (P0.3)
//

import Foundation
import CloudKit

extension CloudKitMovieNightStore {

    // MARK: - Decode helpers

    func decodeEvent(record: CKRecord, fallbackGroupId: String) -> MovieNightEvent? {
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let groupId = (record[groupIdKey] as? String) ?? fallbackGroupId
        guard
            let proposedStart = record[proposedStartKey] as? Date,
            let createdAt = record[createdAtKey] as? Date,
            let updatedAt = record[updatedAtKey] as? Date,
            let proposerUserIdString = record[proposerUserIdKey] as? String,
            let proposerUserId = UUID(uuidString: proposerUserIdString),
            let proposerName = record[proposerNameKey] as? String,
            let statusRaw = record[statusKey] as? String,
            let status = MovieNightEvent.Status(rawValue: statusRaw)
        else { return nil }

        let note = record[noteKey] as? String

        let suggestedMovie: MovieNightMovieRef? = {
            guard
                let movieIdString = record[movieIdKey] as? String,
                let movieId = UUID(uuidString: movieIdString),
                let title = record[movieTitleKey] as? String,
                let year = record[movieYearKey] as? String
            else {
                return nil
            }

            let posterPath = record[moviePosterPathKey] as? String

            let tmdbId: Int? = {
                if let n = record[movieTmdbIdKey] as? NSNumber { return n.intValue }
                if let i = record[movieTmdbIdKey] as? Int { return i }
                return nil
            }()

            return MovieNightMovieRef(
                movieId: movieId,
                title: title,
                year: year,
                posterPath: posterPath,
                tmdbId: tmdbId
            )
        }()

        return MovieNightEvent(
            id: id,
            groupId: groupId,
            proposedStart: proposedStart,
            createdAt: createdAt,
            updatedAt: updatedAt,
            proposerUserId: proposerUserId,
            proposerName: proposerName,
            suggestedMovie: suggestedMovie,
            note: note,
            status: status
        )
    }

    func decodeResponse(record: CKRecord) -> MovieNightResponse? {
        guard
            let eventIdString = record[eventIdKey] as? String,
            let eventId = UUID(uuidString: eventIdString),
            let userIdString = record[userIdKey] as? String,
            let userId = UUID(uuidString: userIdString),
            let userName = record[userNameKey] as? String,
            let decisionRaw = record[decisionKey] as? String,
            let decision = MovieNightResponse.Decision(rawValue: decisionRaw),
            let respondedAt = record[respondedAtKey] as? Date
        else { return nil }

        return MovieNightResponse(
            eventId: eventId,
            userId: userId,
            userName: userName,
            decision: decision,
            respondedAt: respondedAt
        )
    }

    func decodeActivity(record: CKRecord, fallbackGroupId: String) -> MovieNightActivityEvent? {
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let groupId = (record[groupIdKey] as? String) ?? fallbackGroupId
        guard
            let kindRaw = record[kindKey] as? String,
            let kind = MovieNightActivityEvent.Kind(rawValue: kindRaw),
            let createdAt = record[createdAtKey] as? Date,
            let eventIdString = record[eventIdKey] as? String,
            let eventId = UUID(uuidString: eventIdString),
            let eventStart = record[eventStartKey] as? Date,
            let actorUserIdString = record[actorUserIdKey] as? String,
            let actorUserId = UUID(uuidString: actorUserIdString),
            let actorName = record[actorNameKey] as? String
        else { return nil }

        let decision: MovieNightResponse.Decision? = {
            guard let raw = record[decisionKey] as? String else { return nil }
            return MovieNightResponse.Decision(rawValue: raw)
        }()

        let newStatus: MovieNightEvent.Status? = {
            guard let raw = record[newStatusKey] as? String else { return nil }
            return MovieNightEvent.Status(rawValue: raw)
        }()

        let note = record[noteKey] as? String

        return MovieNightActivityEvent(
            id: id,
            groupId: groupId,
            kind: kind,
            createdAt: createdAt,
            eventId: eventId,
            eventStart: eventStart,
            actorUserId: actorUserId,
            actorName: actorName,
            decision: decision,
            newStatus: newStatus,
            note: note
        )
    }


    func decodePreset(record: CKRecord, fallbackGroupId: String) -> MovieRoulettePreset? {
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let groupId = (record[groupIdKey] as? String) ?? fallbackGroupId
        guard
            let name = record[presetNameKey] as? String,
            let updatedAt = record[updatedAtKey] as? Date
        else { return nil }

        let sortIndex: Int = {
            if let number = record[sortIndexKey] as? NSNumber { return number.intValue }
            if let value = record[sortIndexKey] as? Int { return value }
            return 0
        }()

        let movieRefs: [MovieNightMovieRef] = {
            guard let raw = record[presetMovieRefsKey] as? String, let data = raw.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([MovieNightMovieRef].self, from: data)) ?? []
        }()

        return MovieRoulettePreset(
            id: id,
            groupId: groupId,
            name: name,
            sortIndex: sortIndex,
            movieRefs: movieRefs,
            updatedAt: updatedAt
        )
    }

    // MARK: - Response recordName encoding (for deletes)

    struct ParsedResponseRecordName {
        let eventId: UUID
        let userId: UUID
    }

    func parseResponseRecordName(_ recordName: String) -> ParsedResponseRecordName? {
        guard let raw = decodeBase64URL(recordName) else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let eventIdStr = String(parts[1])
        let userIdStr = String(parts[2])
        guard let eventId = UUID(uuidString: eventIdStr), let userId = UUID(uuidString: userIdStr) else { return nil }
        return ParsedResponseRecordName(eventId: eventId, userId: userId)
    }

    func decodeBase64URL(_ s: String) -> String? {
        var b64 = s
        b64 = b64.replacingOccurrences(of: "-", with: "+")
        b64 = b64.replacingOccurrences(of: "_", with: "/")
        let mod = b64.count % 4
        if mod != 0 {
            b64 += String(repeating: "=", count: 4 - mod)
        }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func responseRecordName(groupId: String, eventId: UUID, userId: UUID) -> String {
        // Stabil & safe: base64-url of "gid|eventId|userId".
        let gid = groupId.isEmpty ? "nogroup" : groupId
        let raw = gid + "|" + eventId.uuidString + "|" + userId.uuidString
        let data = raw.data(using: .utf8) ?? Data()
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "+", with: "-")
        b64 = b64.replacingOccurrences(of: "/", with: "_")
        b64 = b64.replacingOccurrences(of: "=", with: "")
        return b64
    }
}

extension MovieNightResponse {
    static func compositeId(eventId: UUID, userId: UUID) -> String {
        "\(eventId.uuidString)_\(userId.uuidString)"
    }
}
