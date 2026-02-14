//
//  SelectedUserSelectionStore.swift
//  filmfreaks
//
//  Persists the user's "active member" selection per group so the user
//  doesn't have to re-select on every app launch.
//

import Foundation

/// Stores the selected user **per group** in `UserDefaults`.
///
/// Why not reuse `CurrentUserIdentityStore`?
/// - That one is intentionally "best effort" + global (used for notification suppression).
/// - Here we want deterministic restore behavior per group.
enum SelectedUserSelectionStore {

    private struct Entry: Codable, Equatable {
        var userIdLowercased: String?
        var userName: String?
    }

    private static let storageKey = "ff.selectedUser.byGroup.v1"
    private static let localGroupKey = "__local__"

    // MARK: - Public API

    static func setSelectedUser(groupId: String?, userId: UUID?, userName: String?) {
        let gk = groupKey(for: groupId)
        var map = loadMap()

        let trimmedName = (userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = Entry(
            userIdLowercased: userId?.uuidString.lowercased(),
            userName: trimmedName.isEmpty ? nil : trimmedName
        )

        // keep storage compact
        if entry.userIdLowercased == nil && entry.userName == nil {
            map.removeValue(forKey: gk)
        } else {
            map[gk] = entry
        }

        saveMap(map)
    }

    static func selectedUserId(groupId: String?) -> UUID? {
        let gk = groupKey(for: groupId)
        guard let raw = loadMap()[gk]?.userIdLowercased else { return nil }
        return UUID(uuidString: raw)
    }

    static func selectedUserName(groupId: String?) -> String? {
        let gk = groupKey(for: groupId)
        return loadMap()[gk]?.userName
    }

    // MARK: - Internals

    private static func groupKey(for groupId: String?) -> String {
        let trimmed = (groupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localGroupKey : trimmed
    }

    private static func loadMap() -> [String: Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private static func saveMap(_ map: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
