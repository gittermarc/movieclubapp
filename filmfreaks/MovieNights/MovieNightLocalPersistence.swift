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

    struct Snapshot: Codable, Equatable {
        var schemaVersion: Int
        var savedAt: Date

        var eventsByGroup: [String: [MovieNightEvent]]
        var responsesByGroup: [String: [MovieNightResponse]]
        var activityByGroup: [String: [MovieNightActivityEvent]]

        static func empty(schemaVersion: Int = 2) -> Snapshot {
            Snapshot(
                schemaVersion: schemaVersion,
                savedAt: .now,
                eventsByGroup: [:],
                responsesByGroup: [:],
                activityByGroup: [:]
            )
        }

        init(
            schemaVersion: Int,
            savedAt: Date,
            eventsByGroup: [String: [MovieNightEvent]],
            responsesByGroup: [String: [MovieNightResponse]],
            activityByGroup: [String: [MovieNightActivityEvent]]
        ) {
            self.schemaVersion = schemaVersion
            self.savedAt = savedAt
            self.eventsByGroup = eventsByGroup
            self.responsesByGroup = responsesByGroup
            self.activityByGroup = activityByGroup
        }

        // Backwards compatibility: Snapshot schema v1 didn't have `activityByGroup`.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)

            self.schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 1
            self.savedAt = (try? c.decode(Date.self, forKey: .savedAt)) ?? .now
            self.eventsByGroup = (try? c.decode([String: [MovieNightEvent]].self, forKey: .eventsByGroup)) ?? [:]
            self.responsesByGroup = (try? c.decode([String: [MovieNightResponse]].self, forKey: .responsesByGroup)) ?? [:]
            self.activityByGroup = (try? c.decode([String: [MovieNightActivityEvent]].self, forKey: .activityByGroup)) ?? [:]
        }
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "movieNights.json") {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let base = (appSupport ?? fm.temporaryDirectory).appendingPathComponent("filmfreaks", isDirectory: true)
        self.fileURL = base.appendingPathComponent(fileName)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    func load() -> Snapshot {
        do {
            try ensureDirectoryExists()
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
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
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            // ignore
        }
    }

    private func ensureDirectoryExists() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }
}
