//
//  CurrentUserIdentityStore.swift
//  filmfreaks
//
//  Best-effort identity of the currently selected user.
//  Used to suppress notifications for the user's own actions.
//

import Foundation

enum CurrentUserIdentityStore {

    private static let idKey = "ff.currentUser.id.v1"
    private static let nameKey = "ff.currentUser.name.v1"

    static func setCurrentUser(id: UUID?, name: String?) {
        if let id {
            UserDefaults.standard.set(id.uuidString.lowercased(), forKey: idKey)
        } else {
            UserDefaults.standard.removeObject(forKey: idKey)
        }

        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: nameKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: nameKey)
        }
    }

    static func currentUserId() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: idKey) else { return nil }
        return UUID(uuidString: raw)
    }

    static func currentUserName() -> String? {
        UserDefaults.standard.string(forKey: nameKey)
    }
}
