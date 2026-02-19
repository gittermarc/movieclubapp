//
//  CloudKitMovieStore+Merge.swift
//  filmfreaks
//
//  Split out: 3-way merge helpers and payload decoding.
//

import Foundation
import CloudKit

extension CloudKitMovieStore {

    // MARK: - Merge helpers (3-way merge)

    func sanitizedMovieForCloud(_ movie: Movie) -> Movie {
        var m = movie
        m.ratings = []
        return m
    }

    func decodeMoviePayload(from record: CKRecord) throws -> Movie? {
        guard let data = record[payloadKey] as? Data else {
            return nil
        }

        var decoded = try JSONDecoder().decode(Movie.self, from: data)
        decoded.ratings = []

        // Prefer groupId from record field if present (payload can be legacy/empty).
        if let gid = record[groupIdKey] as? String, !gid.isEmpty {
            decoded.groupId = gid
        }

        return decoded
    }

    func mergeRequired<T: Equatable>(ancestor: T, server: T, client: T) -> T {
        let clientChanged = client != ancestor
        let serverChanged = server != ancestor

        switch (clientChanged, serverChanged) {
        case (false, false):
            return server
        case (true, false):
            return client
        case (false, true):
            return server
        case (true, true):
            // True conflict (both changed differently): server wins to avoid overwriting others.
            return (client == server) ? server : server
        }
    }

    func mergeOptional<T: Equatable>(ancestor: T?, server: T?, client: T?) -> T? {
        let clientChanged = client != ancestor
        let serverChanged = server != ancestor

        switch (clientChanged, serverChanged) {
        case (false, false):
            return server
        case (true, false):
            return client
        case (false, true):
            return server
        case (true, true):
            if client == server { return server }
            // If one side is missing, keep the other. Otherwise: server wins (safer; avoids overwriting others).
            if server == nil { return client }
            if client == nil { return server }
            return server
        }
    }

    func mergeArray<T: Hashable>(ancestor: [T]?, server: [T]?, client: [T]?) -> [T]? {
        let a = ancestor ?? []
        let s = server ?? []
        let c = client ?? []

        let clientChanged = Set(c) != Set(a)
        let serverChanged = Set(s) != Set(a)

        switch (clientChanged, serverChanged) {
        case (false, false):
            return s.isEmpty ? nil : s
        case (true, false):
            return c.isEmpty ? nil : c
        case (false, true):
            return s.isEmpty ? nil : s
        case (true, true):
            // Both changed: union (server order first, then client extras).
            var out = s
            var seen = Set(out)
            for v in c where !seen.contains(v) {
                out.append(v)
                seen.insert(v)
            }
            return out.isEmpty ? nil : out
        }
    }

    func mergeMovies(
        ancestor: Movie?,
        server: Movie,
        client: Movie,
        forcedGroupId: String?
    ) -> Movie {
        // If we don't have an ancestor, use the server record as a stable baseline.
        let a = ancestor ?? server

        var merged = server

        // Required
        merged.title = mergeRequired(ancestor: a.title, server: server.title, client: client.title)
        merged.year  = mergeRequired(ancestor: a.year,  server: server.year,  client: client.year)

        // Optionals / scalars
        merged.tmdbRating      = mergeOptional(ancestor: a.tmdbRating, server: server.tmdbRating, client: client.tmdbRating)
        merged.posterPath      = mergeOptional(ancestor: a.posterPath, server: server.posterPath, client: client.posterPath)
        merged.watchedDate     = mergeOptional(ancestor: a.watchedDate, server: server.watchedDate, client: client.watchedDate)
        merged.watchedLocation = mergeOptional(ancestor: a.watchedLocation, server: server.watchedLocation, client: client.watchedLocation)
        merged.tmdbId          = mergeOptional(ancestor: a.tmdbId, server: server.tmdbId, client: client.tmdbId)

        merged.suggestedBy     = mergeOptional(ancestor: a.suggestedBy, server: server.suggestedBy, client: client.suggestedBy)
        merged.groupName       = mergeOptional(ancestor: a.groupName, server: server.groupName, client: client.groupName)

        // Arrays
        merged.genres     = mergeArray(ancestor: a.genres, server: server.genres, client: client.genres)
        merged.genreIds   = mergeArray(ancestor: a.genreIds, server: server.genreIds, client: client.genreIds)
        merged.keywords   = mergeArray(ancestor: a.keywords, server: server.keywords, client: client.keywords)
        merged.keywordIds = mergeArray(ancestor: a.keywordIds, server: server.keywordIds, client: client.keywordIds)
        merged.cast       = mergeArray(ancestor: a.cast, server: server.cast, client: client.cast)
        merged.directors  = mergeArray(ancestor: a.directors, server: server.directors, client: client.directors)

        // Ratings are stored separately (MovieRating records) and are not part of the Movie payload in CloudKit.
        merged.ratings = []

        // Group routing safety:
        // - record field `groupIdKey` is authoritative for Cloud routing
        // - payload value should not "jump" across groups
        if let forcedGroupId {
            merged.groupId = forcedGroupId
        }

        return merged
    }
}
