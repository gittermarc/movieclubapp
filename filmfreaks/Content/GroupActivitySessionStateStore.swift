//
//  GroupActivitySessionStateStore.swift
//  filmfreaks
//
//  Created on 15.04.26.
//

import Foundation

enum GroupActivitySessionStateStore {

    private struct AppLaunchState: Codable, Equatable {
        var previousLaunchAt: Date?
        var currentLaunchAt: Date
    }

    private struct ViewedEntry: Codable, Equatable {
        var lastViewedAt: Date
    }

    private static let appLaunchStateKey = "ff.groupActivity.appLaunch.v1"
    private static let viewedByScopeKey = "ff.groupActivity.viewedByScope.v1"

    private static let localGroupKey = "__local__"
    private static let anonymousUserKey = "__anonymous__"

    static func registerAppLaunch(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        let previousState = loadAppLaunchState(defaults: defaults)
        let nextState = AppLaunchState(
            previousLaunchAt: previousState?.currentLaunchAt,
            currentLaunchAt: now
        )
        saveAppLaunchState(nextState, defaults: defaults)
    }

    static func unseenThreshold(
        groupId: String?,
        userId: UUID?,
        userName: String?,
        defaults: UserDefaults = .standard
    ) -> Date {
        let launchState = loadAppLaunchState(defaults: defaults)
        let sessionBaseline = launchState?.previousLaunchAt ?? launchState?.currentLaunchAt ?? Date()

        guard let lastViewedAt = lastViewedAt(
            groupId: groupId,
            userId: userId,
            userName: userName,
            defaults: defaults
        ) else {
            return sessionBaseline
        }

        return max(sessionBaseline, lastViewedAt)
    }

    static func markViewed(
        groupId: String?,
        userId: UUID?,
        userName: String?,
        viewedAt: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        let scopeKey = makeScopeKey(groupId: groupId, userId: userId, userName: userName)
        var map = loadViewedMap(defaults: defaults)
        map[scopeKey] = ViewedEntry(lastViewedAt: viewedAt)
        saveViewedMap(map, defaults: defaults)
    }

    static func lastViewedAt(
        groupId: String?,
        userId: UUID?,
        userName: String?,
        defaults: UserDefaults = .standard
    ) -> Date? {
        let scopeKey = makeScopeKey(groupId: groupId, userId: userId, userName: userName)
        return loadViewedMap(defaults: defaults)[scopeKey]?.lastViewedAt
    }

    private static func makeScopeKey(groupId: String?, userId: UUID?, userName: String?) -> String {
        let normalizedGroup = normalizeGroupId(groupId)
        let normalizedUser = normalizeUserKey(userId: userId, userName: userName)
        return "\(normalizedGroup)|\(normalizedUser)"
    }

    private static func normalizeGroupId(_ groupId: String?) -> String {
        let trimmed = (groupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? localGroupKey : trimmed.lowercased()
    }

    private static func normalizeUserKey(userId: UUID?, userName: String?) -> String {
        if let userId {
            return userId.uuidString.lowercased()
        }

        let trimmedName = (userName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return anonymousUserKey
        }

        return trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func loadAppLaunchState(defaults: UserDefaults) -> AppLaunchState? {
        guard let data = defaults.data(forKey: appLaunchStateKey) else { return nil }
        return try? JSONDecoder().decode(AppLaunchState.self, from: data)
    }

    private static func saveAppLaunchState(_ state: AppLaunchState, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: appLaunchStateKey)
    }

    private static func loadViewedMap(defaults: UserDefaults) -> [String: ViewedEntry] {
        guard let data = defaults.data(forKey: viewedByScopeKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ViewedEntry].self, from: data)) ?? [:]
    }

    private static func saveViewedMap(_ map: [String: ViewedEntry], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: viewedByScopeKey)
    }
}
