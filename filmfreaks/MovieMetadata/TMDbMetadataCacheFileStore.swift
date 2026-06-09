//
//  TMDbMetadataCacheFileStore.swift
//  filmfreaks
//

import Foundation

actor TMDbMetadataCacheFileStore: TMDbMetadataCacheStore {
    private let fileManager: FileManager
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let cacheRoot = baseDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = cacheRoot.appendingPathComponent("TMDbMetadata", isDirectory: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func read<Payload: Decodable & Sendable>(
        _ type: Payload.Type,
        for key: TMDbMetadataCacheKey,
        now: Date = Date()
    ) async -> TMDbMetadataCacheRead<Payload>? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let entry = try decoder.decode(TMDbMetadataCacheEntry.self, from: data)
            let freshness = entry.freshness(now: now)

            if entry.isNegative {
                return TMDbMetadataCacheRead(entry: entry, freshness: freshness, payload: nil)
            }

            guard let payloadData = entry.payload else {
                try? fileManager.removeItem(at: url)
                return nil
            }

            let payload = try decoder.decode(Payload.self, from: payloadData)
            return TMDbMetadataCacheRead(entry: entry, freshness: freshness, payload: payload)
        } catch {
            try? fileManager.removeItem(at: url)
            return nil
        }
    }

    func write<Payload: Encodable & Sendable>(
        _ payload: Payload?,
        for key: TMDbMetadataCacheKey,
        policy: TMDbMetadataCachePolicy,
        now: Date = Date(),
        isNegative: Bool = false
    ) async {
        ensureDirectoryExists()
        do {
            let payloadData = try payload.map { try encoder.encode($0) }
            let dates = policy.dates(now: now)
            let entry = TMDbMetadataCacheEntry(
                key: key,
                createdAt: now,
                expiresAt: dates.expiresAt,
                staleUntil: dates.staleUntil,
                isNegative: isNegative,
                payload: payloadData
            )
            let data = try encoder.encode(entry)
            try data.write(to: fileURL(for: key), options: [.atomic])
        } catch {
            return
        }
    }

    func removeAll() async {
        try? fileManager.removeItem(at: directory)
        ensureDirectoryExists()
    }

    func totalSizeInBytes() async -> Int {
        totalSize(in: directory)
    }

    func cleanupExpiredEntries(now: Date = Date()) async {
        guard let files = cacheFiles() else { return }
        for file in files {
            do {
                let data = try Data(contentsOf: file)
                let entry = try decoder.decode(TMDbMetadataCacheEntry.self, from: data)
                if entry.freshness(now: now) == .expired {
                    try? fileManager.removeItem(at: file)
                }
            } catch {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func cleanupCorruptedEntries() async {
        guard let files = cacheFiles() else { return }
        for file in files {
            do {
                let data = try Data(contentsOf: file)
                _ = try decoder.decode(TMDbMetadataCacheEntry.self, from: data)
            } catch {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for key: TMDbMetadataCacheKey) -> URL {
        directory.appendingPathComponent(key.fileName, isDirectory: false)
    }

    private func cacheFiles() -> [URL]? {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        return try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
    }

    private func totalSize(in directory: URL) -> Int {
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            total += values.fileSize ?? 0
        }
        return total
    }
}
