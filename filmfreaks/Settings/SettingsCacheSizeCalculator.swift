//
//  SettingsCacheSizeCalculator.swift
//  filmfreaks
//

import Foundation

nonisolated struct SettingsCacheSizeCalculator {
    private let fileManager: FileManager
    private let cachesDirectory: URL?

    init(
        fileManager: FileManager = .default,
        cachesDirectory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    ) {
        self.fileManager = fileManager
        self.cachesDirectory = cachesDirectory
    }

    func totalLocalCacheBytes() -> Int {
        imageCacheBytes() + tmdbMetadataCacheBytes()
    }

    func imageCacheBytes() -> Int {
        guard let cachesDirectory else { return 0 }
        let directory = cachesDirectory.appendingPathComponent("ImageCacheStore", isDirectory: true)
        return totalSize(in: directory)
    }

    func tmdbMetadataCacheBytes() -> Int {
        guard let cachesDirectory else { return 0 }
        let directory = cachesDirectory.appendingPathComponent("TMDbMetadata", isDirectory: true)
        return totalSize(in: directory)
    }

    private func totalSize(in directory: URL) -> Int {
        guard fileManager.fileExists(atPath: directory.path) else {
            return 0
        }

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
