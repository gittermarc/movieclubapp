//
//  GroupContext.swift
//  filmfreaks
//
//  CloudKit Sharing: Persisted routing metadata about a group (zone + scope).
//

import Foundation

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

    /// Load a single context for a groupId.
    static func context(forGroupId groupId: String) -> GroupContext? {
        guard !groupId.isEmpty else { return nil }
        guard let dict = UserDefaults.standard.dictionary(forKey: contextsKey) as? [String: Data] else {
            return nil
        }
        guard let data = dict[groupId] else { return nil }
        return try? JSONDecoder().decode(GroupContext.self, from: data)
    }

    /// Save or update a context.
    static func upsert(_ context: GroupContext) {
        var dict = (UserDefaults.standard.dictionary(forKey: contextsKey) as? [String: Data]) ?? [:]
        if let data = try? JSONEncoder().encode(context) {
            dict[context.id] = data
            UserDefaults.standard.set(dict, forKey: contextsKey)
        }
    }

    /// Remove a context (e.g. user left a shared group).
    static func remove(groupId: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: contextsKey) as? [String: Data]) ?? [:]
        dict.removeValue(forKey: groupId)
        UserDefaults.standard.set(dict, forKey: contextsKey)
    }

    static func all() -> [GroupContext] {
        guard let dict = UserDefaults.standard.dictionary(forKey: contextsKey) as? [String: Data] else {
            return []
        }
        return dict.values.compactMap { try? JSONDecoder().decode(GroupContext.self, from: $0) }
    }
}
