//
//  CloudKitMovieStore+Schema.swift
//  filmfreaks
//
//  Split out: schema / record decoding.
//

import Foundation
import CloudKit

extension CloudKitMovieStore {

    // MARK: - Hilfsfunktion: Record → Movie

    func decodeMovie(from record: CKRecord) throws -> CloudMovieEntry? {
        guard let data = record[payloadKey] as? Data else {
            return nil
        }

        var decoded = try JSONDecoder().decode(Movie.self, from: data)
        decoded.ratings = []
        let isBacklog = (record[isBacklogKey] as? Bool) ?? false

        if let gid = record[groupIdKey] as? String, !gid.isEmpty {
            decoded.groupId = gid
        }

        return CloudMovieEntry(movie: decoded, isBacklog: isBacklog)
    }
}
