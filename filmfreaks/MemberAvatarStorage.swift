//
//  MemberAvatarStorage.swift
//  filmfreaks
//
//  Group-scoped, local storage for member profile images.
//

import Foundation

final class MemberAvatarStorage {

    static let shared = MemberAvatarStorage(
        rootURL: GroupScopedStorage.applicationSupportRootURL()
    )

    private let rootURL: URL
    private let fileManager: FileManager

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func avatarData(memberId: UUID, groupId: String?) -> Data? {
        let url = avatarURL(memberId: memberId, groupId: groupId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func storeAvatar(_ data: Data, memberId: UUID, groupId: String?) throws {
        let url = avatarURL(memberId: memberId, groupId: groupId)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic])
    }

    func removeAvatar(memberId: UUID, groupId: String?) throws {
        let url = avatarURL(memberId: memberId, groupId: groupId)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func avatarURL(memberId: UUID, groupId: String?) -> URL {
        GroupScopedStorage.memberAvatarURL(
            root: rootURL,
            groupId: groupId,
            memberId: memberId
        )
    }
}
