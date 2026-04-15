//
//  MovieNightLocalPersistence.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation

/// Very small local persistence layer for P0.
///
/// Stores all movie night data in a single JSON file in Application Support.
actor MovieNightLocalPersistence {

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601WithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    struct Snapshot: Codable, Equatable {
        var schemaVersion: Int
        var savedAt: Date

        var eventsByGroup: [String: [MovieNightEvent]]
        var responsesByGroup: [String: [MovieNightResponse]]
        var activityByGroup: [String: [MovieNightActivityEvent]]
        var presetsByGroup: [String: [MovieRoulettePreset]]

        static func empty(schemaVersion: Int = 3) -> Snapshot {
            Snapshot(
                schemaVersion: schemaVersion,
                savedAt: .now,
                eventsByGroup: [:],
                responsesByGroup: [:],
                activityByGroup: [:],
                presetsByGroup: [:]
            )
        }

        init(
            schemaVersion: Int,
            savedAt: Date,
            eventsByGroup: [String: [MovieNightEvent]],
            responsesByGroup: [String: [MovieNightResponse]],
            activityByGroup: [String: [MovieNightActivityEvent]],
            presetsByGroup: [String: [MovieRoulettePreset]]
        ) {
            self.schemaVersion = schemaVersion
            self.savedAt = savedAt
            self.eventsByGroup = eventsByGroup
            self.responsesByGroup = responsesByGroup
            self.activityByGroup = activityByGroup
            self.presetsByGroup = presetsByGroup
        }

        // Backwards compatibility: Snapshot schema v1 didn't have `activityByGroup`.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            self.schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 1
            self.savedAt = (try? c.decode(Date.self, forKey: .savedAt)) ?? .now
            self.eventsByGroup = (try? c.decode([String: [MovieNightEvent]].self, forKey: .eventsByGroup)) ?? [:]
            self.responsesByGroup = (try? c.decode([String: [MovieNightResponse]].self, forKey: .responsesByGroup)) ?? [:]
            self.activityByGroup = (try? c.decode([String: [MovieNightActivityEvent]].self, forKey: .activityByGroup)) ?? [:]
            self.presetsByGroup = (try? c.decode([String: [MovieRoulettePreset]].self, forKey: .presetsByGroup)) ?? [:]
        }
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    init(fileName: String = "movieNights.json", baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let base = (baseDirectory ?? appSupport ?? fileManager.temporaryDirectory)
            .appendingPathComponent("filmfreaks", isDirectory: true)
        self.fileURL = base.appendingPathComponent(fileName)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSince1970)
        }
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            let rawValue = try container.decode(String.self)

            if let date = MovieNightLocalPersistence.iso8601WithFractionalSeconds.date(from: rawValue) {
                return date
            }

            if let date = MovieNightLocalPersistence.iso8601WithoutFractionalSeconds.date(from: rawValue) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported persisted date value: \(rawValue)"
            )
        }
        self.decoder = dec
    }

    func load() -> Snapshot {
        do {
            try ensureDirectoryExists()
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return .empty()
            }
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(Snapshot.self, from: data)
        } catch {
            // Best-effort persistence for P0/P2.
            return .empty()
        }
    }

    func save(_ snapshot: Snapshot) {
        do {
            try ensureDirectoryExists()
            var copy = snapshot
            copy.savedAt = .now
            let data = try encoder.encode(copy)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Best-effort persistence for P0/P2.
        }
    }

    func deleteLocalFile() {
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            // ignore
        }
    }

    private func ensureDirectoryExists() throws {
        let dir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }

    func fileURLForTesting() -> URL {
        fileURL
    }
}
