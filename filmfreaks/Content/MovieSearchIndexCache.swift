//
//  MovieSearchIndexCache.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

import Foundation

/// Caches a normalized "haystack" string per movie so in-list search does not
/// rebuild large strings (join + folding) for every render / keystroke.
///
/// - Note: The fingerprint uses Swift's `Hasher` which is intentionally not stable
///   across launches. That's fine: this cache is in-memory only.
nonisolated final class MovieSearchIndexCache: @unchecked Sendable {

    private let lock = NSLock()
    private var haystackById: [UUID: String] = [:]
    private var fingerprintById: [UUID: Int] = [:]

    func normalizedTokens(for rawQuery: String) -> [String] {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalized = normalize(trimmed)
        let tokens = normalized
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        return tokens
    }

    func matches(movie: Movie, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let haystack = normalizedHaystack(for: movie)
        return tokens.allSatisfy { haystack.contains($0) }
    }

    // MARK: - Internals

    private func normalizedHaystack(for movie: Movie) -> String {
        let fp = fingerprint(for: movie)

        if let cached = cachedHaystack(for: movie.id, fingerprint: fp) {
            return cached
        }

        var fields: [String] = [movie.title, movie.year]

        if let location = movie.watchedLocation, !location.isEmpty {
            fields.append(location)
        }

        if let suggestedBy = movie.suggestedBy, !suggestedBy.isEmpty {
            fields.append(suggestedBy)
        }

        if let cast = movie.cast, !cast.isEmpty {
            fields.append(cast.map { $0.name }.joined(separator: " "))
        }

        if let directors = movie.directors, !directors.isEmpty {
            fields.append(directors.map { $0.name }.joined(separator: " "))
        }

        if let genres = movie.genres, !genres.isEmpty {
            fields.append(genres.joined(separator: " "))
        }

        if let keywords = movie.keywords, !keywords.isEmpty {
            fields.append(keywords.joined(separator: " "))
        }

        let haystack = normalize(fields.joined(separator: " "))
        store(haystack: haystack, for: movie.id, fingerprint: fp)
        return haystack
    }

    private func cachedHaystack(for movieId: UUID, fingerprint: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard let existing = haystackById[movieId], fingerprintById[movieId] == fingerprint else {
            return nil
        }

        return existing
    }

    private func store(haystack: String, for movieId: UUID, fingerprint: Int) {
        lock.lock()
        haystackById[movieId] = haystack
        fingerprintById[movieId] = fingerprint
        lock.unlock()
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func fingerprint(for movie: Movie) -> Int {
        var hasher = Hasher()
        hasher.combine(movie.title)
        hasher.combine(movie.year)
        hasher.combine(movie.watchedLocation ?? "")
        hasher.combine(movie.suggestedBy ?? "")

        if let cast = movie.cast {
            hasher.combine(cast.count)
            for member in cast {
                hasher.combine(member.personId)
                hasher.combine(member.name)
            }
        } else {
            hasher.combine(0)
        }

        if let directors = movie.directors {
            hasher.combine(directors.count)
            for member in directors {
                hasher.combine(member.personId)
                hasher.combine(member.name)
            }
        } else {
            hasher.combine(0)
        }

        if let genres = movie.genres {
            hasher.combine(genres.count)
            for g in genres { hasher.combine(g) }
        } else {
            hasher.combine(0)
        }

        if let keywords = movie.keywords {
            hasher.combine(keywords.count)
            for k in keywords { hasher.combine(k) }
        } else {
            hasher.combine(0)
        }

        return hasher.finalize()
    }
}
