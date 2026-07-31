//
//  MemberCloudDirtyJournal.swift
//  filmfreaks
//
//  Durable, group-scoped journal for pending GroupMember CloudKit writes.
//

import Foundation

enum MemberCloudDirtyJournalOperation: String, Codable, Equatable {
    case upsert
    case delete
}

struct MemberCloudDirtyJournalEntry: Codable, Equatable, Identifiable {
    let memberId: UUID
    let operation: MemberCloudDirtyJournalOperation
    let token: UUID
    let updatedAt: Date
    let member: User?

    var id: UUID { memberId }
}

final class MemberCloudDirtyJournal {

    static let shared = MemberCloudDirtyJournal(
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

    func entries(groupId: String?) -> [MemberCloudDirtyJournalEntry] {
        let url = journalURL(groupId: groupId)
        guard fileManager.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([MemberCloudDirtyJournalEntry].self, from: data)
            return decoded.sorted { $0.updatedAt < $1.updatedAt }
        } catch {
            return []
        }
    }

    @discardableResult
    func recordUpsert(
        member: User,
        groupId: String?,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MemberCloudDirtyJournalEntry {
        let entry = MemberCloudDirtyJournalEntry(
            memberId: member.id,
            operation: .upsert,
            token: token,
            updatedAt: updatedAt,
            member: member
        )

        upsert(entry, groupId: groupId)
        return entry
    }

    @discardableResult
    func recordDelete(
        memberId: UUID,
        groupId: String?,
        token: UUID = UUID(),
        updatedAt: Date = Date()
    ) -> MemberCloudDirtyJournalEntry {
        let entry = MemberCloudDirtyJournalEntry(
            memberId: memberId,
            operation: .delete,
            token: token,
            updatedAt: updatedAt,
            member: nil
        )

        upsert(entry, groupId: groupId)
        return entry
    }

    func remove(memberId: UUID, matchingToken token: UUID, groupId: String?) {
        let retained = entries(groupId: groupId).filter { entry in
            entry.memberId != memberId || entry.token != token
        }
        write(retained, groupId: groupId)
    }

    func removeAll(groupId: String?) {
        write([], groupId: groupId)
    }
}

private extension MemberCloudDirtyJournal {

    func journalURL(groupId: String?) -> URL {
        GroupScopedStorage.memberCloudDirtyJournalURL(root: rootURL, groupId: groupId)
    }

    func upsert(_ entry: MemberCloudDirtyJournalEntry, groupId: String?) {
        var current = entries(groupId: groupId).filter { $0.memberId != entry.memberId }
        current.append(entry)
        write(current.sorted { $0.updatedAt < $1.updatedAt }, groupId: groupId)
    }

    func write(_ entries: [MemberCloudDirtyJournalEntry], groupId: String?) {
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
            assertionFailure("MemberCloudDirtyJournal write failed: \(error)")
        }
    }
}
