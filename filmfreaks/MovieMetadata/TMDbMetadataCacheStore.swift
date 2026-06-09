//
//  TMDbMetadataCacheStore.swift
//  filmfreaks
//

import Foundation

nonisolated protocol TMDbMetadataCacheStore: Sendable {
    func read<Payload: Decodable & Sendable>(
        _ type: Payload.Type,
        for key: TMDbMetadataCacheKey,
        now: Date
    ) async -> TMDbMetadataCacheRead<Payload>?

    func write<Payload: Encodable & Sendable>(
        _ payload: Payload?,
        for key: TMDbMetadataCacheKey,
        policy: TMDbMetadataCachePolicy,
        now: Date,
        isNegative: Bool
    ) async

    func removeAll() async
    func totalSizeInBytes() async -> Int
    func cleanupExpiredEntries(now: Date) async
    func cleanupCorruptedEntries() async
}
