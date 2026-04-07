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

    static func loadDict(defaults: UserDefaults = .standard) -> [String: Data] {
        (defaults.object(forKey: contextsKey) as? [String: Data]) ?? [:]
    }

    static func saveDict(_ dict: [String: Data], defaults: UserDefaults = .standard) {
        defaults.set(dict, forKey: contextsKey)
    }

    /// Load a single context for a groupId.
    static func context(forGroupId groupId: String, defaults: UserDefaults = .standard) -> GroupContext? {
        guard !groupId.isEmpty else { return nil }
        let dict = loadDict(defaults: defaults)
        guard let data = dict[groupId] else { return nil }
        return try? JSONDecoder().decode(GroupContext.self, from: data)
    }

    /// Save or update a context.
    static func upsert(_ context: GroupContext, defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        var dict = loadDict(defaults: defaults)

        if let existing = dict[context.id],
           let decoded = try? JSONDecoder().decode(GroupContext.self, from: existing),
           decoded == context {
            return
        }

        if let data = try? JSONEncoder().encode(context) {
            dict[context.id] = data
            saveDict(dict, defaults: defaults)

            DispatchQueue.main.async {
                notificationCenter.post(
                    name: .groupContextDidUpsert,
                    object: nil,
                    userInfo: ["groupId": context.id]
                )
            }
        }
    }

    /// Remove a context (e.g. user left a shared group).
    static func remove(groupId: String, defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        var dict = loadDict(defaults: defaults)
        let existed = dict.removeValue(forKey: groupId) != nil
        saveDict(dict, defaults: defaults)

        guard existed else { return }
        DispatchQueue.main.async {
            notificationCenter.post(
                name: .groupContextDidRemove,
                object: nil,
                userInfo: ["groupId": groupId]
            )
        }
    }

    static func all(defaults: UserDefaults = .standard) -> [GroupContext] {
        loadDict(defaults: defaults).values.compactMap { try? JSONDecoder().decode(GroupContext.self, from: $0) }
    }
}
