//
//  MovieCloudDirtyJournal.swift
//  filmfreaks
//
//  Durable, group-scoped journal for pending Movie CloudKit writes.
//

import Foundation

enum MovieCloudDirtyJournalOperation: String, Codable, Equatable {
    case save
    case delete
}

struct MovieCloudDirtyJournalEntry: Codable, Equatable, Identifiable {
    let movieId: UUID
    let operation: MovieCloudDirtyJournalOperation
    let token: UUID
    let updatedAt: Date
    let isBacklog: Bool?
    let movie: Movie?

    var id: UUID { movieId }
}

final class MovieCloudDirtyJournal {
    static let shared = MovieCloudDirtyJournal(
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

    func entries(groupId: String?) -> [MovieCloudDirtyJournalEntry] {
        let url = journalURL(groupId: groupId)
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([MovieCloudDirtyJournalEntry].self, from: data)
            return decoded.sorted { $0.updatedAt < $1.updatedAt }
        } catch {
            return []
        }
    }

    @discardableResult
    func recordSave(
        movie: Movie,
        isBacklog: Bool,
        groupId: String?,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieCloudDirtyJournalEntry {
        let entry = MovieCloudDirtyJournalEntry(
            movieId: movie.id,
            operation: .save,
            token: token,
            updatedAt: updatedAt,
            isBacklog: isBacklog,
            movie: movie
        )

        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordDelete(
        movieID: UUID,
        groupId: String?,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MovieCloudDirtyJournalEntry {
        let entry = MovieCloudDirtyJournalEntry(
            movieId: movieID,
            operation: .delete,
            token: token,
            updatedAt: updatedAt,
            isBacklog: nil,
            movie: nil
        )

        upsert(entry, groupId: groupId)
        return entry
    }

    func remove(movieID: UUID, matchingToken token: UUID, groupId: String?) {
        let filtered = entries(groupId: groupId).filter { entry in
            !(entry.movieId == movieID && entry.token == token)
        }
        write(filtered, groupId: groupId)
    }

    func removeAll(groupId: String?) {
        write([], groupId: groupId)
    }
}

private extension MovieCloudDirtyJournal {
    func journalURL(groupId: String?) -> URL {
        GroupScopedStorage.movieCloudDirtyJournalURL(root: rootURL, groupId: groupId)
    }

    func upsert(_ entry: MovieCloudDirtyJournalEntry, groupId: String?) {
        var current = entries(groupId: groupId).filter { $0.movieId != entry.movieId }
        current.append(entry)
        write(current.sorted { $0.updatedAt < $1.updatedAt }, groupId: groupId)
    }

    func write(_ entries: [MovieCloudDirtyJournalEntry], groupId: String?) {
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
            assertionFailure("MovieCloudDirtyJournal write failed: \(error)")
        }
    }
}
