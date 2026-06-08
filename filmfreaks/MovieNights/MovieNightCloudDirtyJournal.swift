//
//  MovieNightCloudDirtyJournal.swift
//  filmfreaks
//
//  Durable, group-scoped journal for pending MovieNight CloudKit writes.
//

import Foundation

enum MovieNightCloudDirtyJournalRecordType: String, Codable, Equatable, Hashable {
    case event
    case response
    case activity
    case preset
}

enum MovieNightCloudDirtyJournalOperation: String, Codable, Equatable, Hashable {
    case save
    case delete
}

struct MovieNightCloudDirtyJournalEntry: Codable, Equatable, Identifiable {
    let groupId: String
    let recordType: MovieNightCloudDirtyJournalRecordType
    let recordId: String
    let operation: MovieNightCloudDirtyJournalOperation
    let token: UUID
    let updatedAt: Date
    let event: MovieNightEvent?
    let response: MovieNightResponse?
    let responseEventId: UUID?
    let responseUserId: UUID?
    let activity: MovieNightActivityEvent?
    let preset: MovieRoulettePreset?

    var id: String { "\(groupId):\(recordType.rawValue):\(recordId)" }
}

final class MovieNightCloudDirtyJournal {
    static let shared = MovieNightCloudDirtyJournal(
        rootURL: GroupScopedStorage.applicationSupportRootURL()
    )

    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        self.decoder = decoder
    }

    func entries(groupId: String) -> [MovieNightCloudDirtyJournalEntry] {
        readEntries(at: journalURL(groupId: groupId))
    }

    func entriesForAllGroups() -> [MovieNightCloudDirtyJournalEntry] {
        let groupsURL = rootURL.appendingPathComponent(GroupScopedStorage.groupsFolderName, isDirectory: true)
        guard let groupDirectories = try? fileManager.contentsOfDirectory(
            at: groupsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let entries = groupDirectories.flatMap { directory -> [MovieNightCloudDirtyJournalEntry] in
            let isDirectory = (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { return [] }
            return readEntries(at: directory.appendingPathComponent(Self.fileName))
        }

        return entries.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt < rhs.updatedAt
            }
            return lhs.id < rhs.id
        }
    }

    func groupIdsWithEntries() -> [String] {
        Array(Set(entriesForAllGroups().map(\.groupId))).sorted()
    }

    @discardableResult
    func recordEventSave(
        _ event: MovieNightEvent,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = MovieNightCloudDirtyJournalEntry(
            groupId: groupId,
            recordType: .event,
            recordId: event.id.uuidString,
            operation: .save,
            token: token,
            updatedAt: updatedAt,
            event: event,
            response: nil,
            responseEventId: nil,
            responseUserId: nil,
            activity: nil,
            preset: nil
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordEventDelete(
        eventId: UUID,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = deleteEntry(
            groupId: groupId,
            recordType: .event,
            recordId: eventId.uuidString,
            token: token,
            updatedAt: updatedAt
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordResponseSave(
        _ response: MovieNightResponse,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = MovieNightCloudDirtyJournalEntry(
            groupId: groupId,
            recordType: .response,
            recordId: response.id,
            operation: .save,
            token: token,
            updatedAt: updatedAt,
            event: nil,
            response: response,
            responseEventId: response.eventId,
            responseUserId: response.userId,
            activity: nil,
            preset: nil
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordResponseDelete(
        eventId: UUID,
        userId: UUID,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = MovieNightCloudDirtyJournalEntry(
            groupId: groupId,
            recordType: .response,
            recordId: Self.responseRecordId(eventId: eventId, userId: userId),
            operation: .delete,
            token: token,
            updatedAt: updatedAt,
            event: nil,
            response: nil,
            responseEventId: eventId,
            responseUserId: userId,
            activity: nil,
            preset: nil
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordActivitySave(
        _ activity: MovieNightActivityEvent,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = MovieNightCloudDirtyJournalEntry(
            groupId: groupId,
            recordType: .activity,
            recordId: activity.id.uuidString,
            operation: .save,
            token: token,
            updatedAt: updatedAt,
            event: nil,
            response: nil,
            responseEventId: nil,
            responseUserId: nil,
            activity: activity,
            preset: nil
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordActivityDelete(
        activityId: UUID,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = deleteEntry(
            groupId: groupId,
            recordType: .activity,
            recordId: activityId.uuidString,
            token: token,
            updatedAt: updatedAt
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordPresetSave(
        _ preset: MovieRoulettePreset,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = MovieNightCloudDirtyJournalEntry(
            groupId: groupId,
            recordType: .preset,
            recordId: preset.id.uuidString,
            operation: .save,
            token: token,
            updatedAt: updatedAt,
            event: nil,
            response: nil,
            responseEventId: nil,
            responseUserId: nil,
            activity: nil,
            preset: preset
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordPresetDelete(
        presetId: UUID,
        groupId: String,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieNightCloudDirtyJournalEntry {
        let entry = deleteEntry(
            groupId: groupId,
            recordType: .preset,
            recordId: presetId.uuidString,
            token: token,
            updatedAt: updatedAt
        )
        upsert(entry, groupId: groupId)
        return entry
    }

    func remove(
        recordType: MovieNightCloudDirtyJournalRecordType,
        recordId: String,
        matchingToken token: UUID,
        groupId: String
    ) {
        let filtered = entries(groupId: groupId).filter { entry in
            !(entry.recordType == recordType && entry.recordId == recordId && entry.token == token)
        }
        write(filtered, groupId: groupId)
    }

    func removeAll(groupId: String) {
        write([], groupId: groupId)
    }

    static func responseRecordId(eventId: UUID, userId: UUID) -> String {
        "\(eventId.uuidString)_\(userId.uuidString)"
    }
}

private extension MovieNightCloudDirtyJournal {
    static let fileName = "movie_night_cloud_dirty_journal.json"

    func journalURL(groupId: String) -> URL {
        GroupScopedStorage.movieNightCloudDirtyJournalURL(root: rootURL, groupId: groupId)
    }

    func deleteEntry(
        groupId: String,
        recordType: MovieNightCloudDirtyJournalRecordType,
        recordId: String,
        token: UUID,
        updatedAt: Date
    ) -> MovieNightCloudDirtyJournalEntry {
        MovieNightCloudDirtyJournalEntry(
            groupId: groupId,
            recordType: recordType,
            recordId: recordId,
            operation: .delete,
            token: token,
            updatedAt: updatedAt,
            event: nil,
            response: nil,
            responseEventId: nil,
            responseUserId: nil,
            activity: nil,
            preset: nil
        )
    }

    func upsert(_ entry: MovieNightCloudDirtyJournalEntry, groupId: String) {
        var current = entries(groupId: groupId).filter { existing in
            !(existing.recordType == entry.recordType && existing.recordId == entry.recordId)
        }
        current.append(entry)
        write(current.sorted { $0.updatedAt < $1.updatedAt }, groupId: groupId)
    }

    func readEntries(at url: URL) -> [MovieNightCloudDirtyJournalEntry] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([MovieNightCloudDirtyJournalEntry].self, from: data)
            return decoded.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhs.id < rhs.id
            }
        } catch {
            return []
        }
    }

    func write(_ entries: [MovieNightCloudDirtyJournalEntry], groupId: String) {
        let url = journalURL(groupId: groupId)

        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if entries.isEmpty {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                return
            }

            let data = try encoder.encode(entries)
            try data.write(to: url, options: [.atomic])
        } catch {
            assertionFailure("MovieNightCloudDirtyJournal write failed: \(error)")
        }
    }
}
