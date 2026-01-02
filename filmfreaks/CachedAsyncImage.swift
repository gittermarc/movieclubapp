//
//  CachedAsyncImage.swift
//  filmfreaks
//
//  Lightweight image loader with memory + disk cache.
//  Designed as a drop-in replacement for SwiftUI.AsyncImage(url:content:).
//

internal import SwiftUI
internal import UIKit
import CryptoKit

// MARK: - Disk + memory image cache

actor ImageCacheStore {
    static let shared = ImageCacheStore()

    private let memory = NSCache<NSString, NSData>()
    private let fm = FileManager.default
    private let directory: URL
    private let maxDiskBytes: Int
    private var inFlight: [URL: Task<Data, Error>] = [:]

    init(maxDiskBytes: Int = 250 * 1024 * 1024) { // 250 MB
        self.maxDiskBytes = maxDiskBytes

        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("ImageCacheStore", isDirectory: true)

        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        // Reasonable defaults for memory cache; NSData cost = bytes
        memory.totalCostLimit = 60 * 1024 * 1024 // 60 MB
        memory.countLimit = 400
    }

    func data(for url: URL) async throws -> Data {
        // 1) Memory
        let key = cacheKey(for: url) as NSString
        if let cached = memory.object(forKey: key) {
            return Data(referencing: cached)
        }

        // 2) Disk
        let fileURL = fileURL(for: url)
        if let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) {
            memory.setObject(data as NSData, forKey: key, cost: data.count)
            // Touch for LRU-ish behavior
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            return data
        }

        // 3) Network (dedupe concurrent downloads)
        if let task = inFlight[url] {
            let data = try await task.value
            memory.setObject(data as NSData, forKey: key, cost: data.count)
            return data
        }

        let task = Task<Data, Error> {
            var request = URLRequest(url: url)
            // Leverage system HTTP cache if possible, but we still persist explicitly on disk.
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }

            // Store to caches directory
            try? data.write(to: fileURL, options: [.atomic])
            memory.setObject(data as NSData, forKey: key, cost: data.count)

            // Best-effort trim
            await trimIfNeeded()

            return data
        }

        inFlight[url] = task
        defer { inFlight[url] = nil }

        return try await task.value
    }

    func removeAll() async {
        memory.removeAllObjects()
        try? fm.removeItem(at: directory)
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Helpers

    private func cacheKey(for url: URL) -> String {
        // SHA256 keeps filenames short and filesystem-safe.
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func fileURL(for url: URL) -> URL {
        directory.appendingPathComponent(cacheKey(for: url) + ".img", isDirectory: false)
    }

    private func trimIfNeeded() async {
        // Keep it simple: if over limit, delete oldest files first (by modification date).
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            return
        }

        var total = 0
        var entries: [(url: URL, size: Int, date: Date)] = []

        for f in files {
            let values = try? f.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let size = values?.fileSize ?? 0
            let date = values?.contentModificationDate ?? Date.distantPast
            total += size
            entries.append((f, size, date))
        }

        guard total > maxDiskBytes else { return }

        entries.sort { $0.date < $1.date } // oldest first

        var bytesToFree = total - maxDiskBytes
        for e in entries where bytesToFree > 0 {
            try? fm.removeItem(at: e.url)
            bytesToFree -= e.size
        }
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?,
         scale: CGFloat = 1.0,
         transaction: Transaction = Transaction(),
         @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await load()
            }
    }

    @MainActor
    private func setPhase(_ newPhase: AsyncImagePhase) {
        withTransaction(transaction) {
            phase = newPhase
        }
    }

    private func load() async {
        guard let url else {
            await MainActor.run { setPhase(.empty) }
            return
        }

        await MainActor.run { setPhase(.empty) }

        do {
            let data = try await ImageCacheStore.shared.data(for: url)

            if let uiImage = UIImage(data: data, scale: scale) {
                let image = Image(uiImage: uiImage)
                await MainActor.run { setPhase(.success(image)) }
            } else {
                await MainActor.run { setPhase(.failure(URLError(.cannotDecodeContentData))) }
            }
        } catch {
            await MainActor.run { setPhase(.failure(error)) }
        }
    }
}
