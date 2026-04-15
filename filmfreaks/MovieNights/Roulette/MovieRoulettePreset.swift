//
//  MovieRoulettePreset.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

nonisolated struct MovieRoulettePreset: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var groupId: String
    var name: String
    var sortIndex: Int
    var movieRefs: [MovieNightMovieRef]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        groupId: String,
        name: String,
        sortIndex: Int,
        movieRefs: [MovieNightMovieRef],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.groupId = groupId
        self.name = name
        self.sortIndex = sortIndex
        self.movieRefs = movieRefs
        self.updatedAt = updatedAt
    }

    nonisolated var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated var displayName: String {
        let trimmed = trimmedName
        return trimmed.isEmpty ? "Neue Auswahl" : trimmed
    }

    nonisolated var movieCount: Int {
        movieRefs.count
    }
}

extension MovieRoulettePreset {
    nonisolated static func == (lhs: MovieRoulettePreset, rhs: MovieRoulettePreset) -> Bool {
        lhs.id == rhs.id &&
        lhs.groupId == rhs.groupId &&
        lhs.name == rhs.name &&
        lhs.sortIndex == rhs.sortIndex &&
        lhs.movieRefs == rhs.movieRefs &&
        normalizedUpdatedAt(lhs.updatedAt) == normalizedUpdatedAt(rhs.updatedAt)
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(groupId)
        hasher.combine(name)
        hasher.combine(sortIndex)
        hasher.combine(movieRefs)
        hasher.combine(Self.normalizedUpdatedAt(updatedAt))
    }

    nonisolated private static func normalizedUpdatedAt(_ date: Date) -> Double {
        let milliseconds = (date.timeIntervalSince1970 * 1000).rounded(.toNearestOrAwayFromZero)
        return milliseconds / 1000
    }
}

extension MovieRoulettePreset {
    nonisolated static func sortOrder(lhs: MovieRoulettePreset, rhs: MovieRoulettePreset) -> Bool {
        if lhs.sortIndex != rhs.sortIndex {
            return lhs.sortIndex < rhs.sortIndex
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    nonisolated static func normalized(_ presets: [MovieRoulettePreset], groupId: String) -> [MovieRoulettePreset] {
        presets
            .sorted(by: sortOrder)
            .enumerated()
            .map { index, preset in
                var copy = preset
                copy.groupId = groupId
                copy.sortIndex = index
                return copy
            }
    }

    nonisolated static func deduplicatedMovieRefs(_ refs: [MovieNightMovieRef]) -> [MovieNightMovieRef] {
        var seen: Set<UUID> = []
        var result: [MovieNightMovieRef] = []
        result.reserveCapacity(refs.count)

        for ref in refs {
            guard seen.insert(ref.movieId).inserted else { continue }
            result.append(ref)
        }

        return result
    }
}
