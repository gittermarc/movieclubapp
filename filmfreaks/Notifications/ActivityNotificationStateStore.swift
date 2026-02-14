//
//  ActivityNotificationStateStore.swift
//  filmfreaks
//
//  Keeps a small dedupe state so CloudKit coalescing / re-delivery
//  doesn't spam the user.
//

import Foundation

final class ActivityNotificationStateStore {

    static let shared = ActivityNotificationStateStore()

    private let key = "ff.notifications.activity.state.v1"
    private let maxRecentPerGroup = 32

    private struct State: Codable, Equatable {
        var recentByGroup: [String: [String]] = [:] // groupId -> [recordID]
    }

    private var state: State

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    func shouldNotify(groupId: String, recordID: String) -> Bool {
        let recent = state.recentByGroup[groupId] ?? []
        return !recent.contains(recordID)
    }

    func markNotified(groupId: String, recordID: String) {
        var recent = state.recentByGroup[groupId] ?? []
        recent.removeAll(where: { $0 == recordID })
        recent.insert(recordID, at: 0)

        if recent.count > maxRecentPerGroup {
            recent = Array(recent.prefix(maxRecentPerGroup))
        }

        state.recentByGroup[groupId] = recent
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
