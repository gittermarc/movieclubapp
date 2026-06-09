//
//  TMDbMetadataCacheEntry.swift
//  filmfreaks
//

import Foundation

nonisolated struct TMDbMetadataCacheEntry: Codable, Equatable, Sendable {
    let key: TMDbMetadataCacheKey
    let createdAt: Date
    let expiresAt: Date
    let staleUntil: Date
    let isNegative: Bool
    let payload: Data?

    init(
        key: TMDbMetadataCacheKey,
        createdAt: Date,
        expiresAt: Date,
        staleUntil: Date,
        isNegative: Bool = false,
        payload: Data?
    ) {
        self.key = key
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.staleUntil = staleUntil
        self.isNegative = isNegative
        self.payload = payload
    }

    func freshness(now: Date) -> TMDbMetadataCacheFreshness {
        if now <= expiresAt { return .fresh }
        if now <= staleUntil { return .stale }
        return .expired
    }
}

nonisolated struct TMDbMetadataCacheRead<Payload: Sendable>: Sendable {
    let entry: TMDbMetadataCacheEntry
    let freshness: TMDbMetadataCacheFreshness
    let payload: Payload?
}
