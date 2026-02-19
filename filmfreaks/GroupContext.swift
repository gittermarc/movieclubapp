//
//  GroupContext.swift
//  filmfreaks
//
//  CloudKit Sharing: Persisted routing metadata about a group (zone + scope).
//

import Foundation

extension Notification.Name {
    static let groupContextDidUpsert = Notification.Name("GroupContextDidUpsert")
    static let groupContextDidRemove = Notification.Name("GroupContextDidRemove")
}

enum GroupScope: String, Codable {
    case `private`
    case shared
}

/// Minimal routing info so the existing CloudKit stores can decide:
/// - which database (private/shared)
/// - which zone
///
/// `id` is the group identifier used throughout the app (and becomes the new "groupId").
struct GroupContext: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var scope: GroupScope

    /// The record zone where this group's data lives.
    var zoneName: String

    /// Owner name for the zone (required for shared zones).
    var ownerName: String

    var isShared: Bool { scope == .shared }
}

final class GroupContextStore {
    private static let contextsKey = "GroupContextsById"

    private static func loadDict() -> [String: Data] {
        (UserDefaults.standard.object(forKey: contextsKey) as? [String: Data]) ?? [:]
    }

    private static func saveDict(_ dict: [String: Data]) {
        UserDefaults.standard.set(dict, forKey: contextsKey)
    }

    /// Load a single context for a groupId.
    static func context(forGroupId groupId: String) -> GroupContext? {
        guard !groupId.isEmpty else { return nil }
        let dict = loadDict()
        guard let data = dict[groupId] else { return nil }
        return try? JSONDecoder().decode(GroupContext.self, from: data)
    }

    /// Save or update a context.
    static func upsert(_ context: GroupContext) {
        var dict = loadDict()

        if let existing = dict[context.id],
           let decoded = try? JSONDecoder().decode(GroupContext.self, from: existing),
           decoded == context {
            return
        }

        if let data = try? JSONEncoder().encode(context) {
            dict[context.id] = data
            saveDict(dict)

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .groupContextDidUpsert,
                    object: nil,
                    userInfo: ["groupId": context.id]
                )
            }
        }
    }

    /// Remove a context (e.g. user left a shared group).
    static func remove(groupId: String) {
        var dict = loadDict()
        let existed = dict.removeValue(forKey: groupId) != nil
        saveDict(dict)

        guard existed else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .groupContextDidRemove,
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }

    static func all() -> [GroupContext] {
        loadDict().values.compactMap { try? JSONDecoder().decode(GroupContext.self, from: $0) }
    }
}
