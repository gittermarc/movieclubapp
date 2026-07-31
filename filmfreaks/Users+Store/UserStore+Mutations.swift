//
//  UserStore+Mutations.swift
//  filmfreaks
//
//  Split from UserStore.swift
//

import Foundation
internal import SwiftUI

enum UserStoreAvatarMutationError: LocalizedError {
    case memberNotFound

    var errorDescription: String? {
        switch self {
        case .memberNotFound:
            return "Das ausgewählte Mitglied wurde nicht mehr gefunden."
        }
    }
}

extension UserStore {

    // MARK: - Public mutations

    /// Neuen User für die aktuelle Gruppe anlegen
    func addUser(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // doppelte Namen vermeiden (case-insensitive)
        if users.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return
        }

        let newUser = User(id: UUID(), name: trimmed)
        users.append(newUser)

        if selectedUser == nil {
            selectedUser = newUser
        }

        queueMemberUpsertForCloud(newUser)
    }

    /// Löscht User an den übergebenen Indizes
    func deleteUsers(at offsets: IndexSet) {
        let deletedUsers = offsets.map { users[$0] }
        users.remove(atOffsets: offsets)

        if let selected = selectedUser, !users.contains(selected) {
            selectedUser = users.first
        }

        for user in deletedUsers {
            try? avatarStorage.removeAvatar(memberId: user.id, groupId: currentGroupId)
            queueMemberDeleteForCloud(memberId: user.id)
        }
    }

    func updateAvatar(_ avatarData: Data, forMemberId memberId: UUID) throws {
        guard let index = users.firstIndex(where: { $0.id == memberId }) else {
            throw UserStoreAvatarMutationError.memberNotFound
        }

        let avatarVersion = UUID().uuidString.lowercased()
        try avatarStorage.storeAvatar(avatarData, memberId: memberId, groupId: currentGroupId)

        var updatedUsers = users
        updatedUsers[index].avatarVersion = avatarVersion
        users = updatedUsers

        let updatedMember = updatedUsers[index]
        if selectedUser?.id == memberId {
            selectedUser = updatedMember
        }

        queueMemberUpsertForCloud(updatedMember)
    }

    func removeAvatar(forMemberId memberId: UUID) throws {
        guard let index = users.firstIndex(where: { $0.id == memberId }) else {
            throw UserStoreAvatarMutationError.memberNotFound
        }

        try avatarStorage.removeAvatar(memberId: memberId, groupId: currentGroupId)

        var updatedUsers = users
        updatedUsers[index].avatarVersion = nil
        users = updatedUsers

        let updatedMember = updatedUsers[index]
        if selectedUser?.id == memberId {
            selectedUser = updatedMember
        }

        queueMemberUpsertForCloud(updatedMember)
    }
}
