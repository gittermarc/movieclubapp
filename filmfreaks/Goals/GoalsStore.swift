//
//  GoalsStore.swift
//  filmfreaks
//
//  Created by OpenAI on 08.04.26.
//

internal import SwiftUI
import Combine

protocol GoalsCloudSyncing {
    func fetchGoals(forGroupId groupId: String?) async throws -> [Int: Int]
    func saveGoal(year: Int, target: Int, groupId: String?) async throws
    func fetchCustomGoals(forGroupId groupId: String?) async throws -> ViewingCustomGoalsPayload
    func saveCustomGoals(_ payload: ViewingCustomGoalsPayload, groupId: String?) async throws
}

extension CloudKitGoalStore: GoalsCloudSyncing {}

@MainActor
final class GoalsStore: ObservableObject {

    @Published private(set) var goalsByYear: [Int: Int] = [:]
    @Published private(set) var customGoals: [ViewingCustomGoal] = []
    @Published private(set) var syncCount: Int = 0

    var isSyncingGoals: Bool { syncCount > 0 }

    let yearlyGoalsStorageKey = "ViewingGoalsByYear.v1"
    let defaultYearlyGoal = 50

    private let userDefaults: UserDefaults
    private let cloudStore: any GoalsCloudSyncing

    init(
        userDefaults: UserDefaults = .standard,
        cloudStore: any GoalsCloudSyncing = CloudKitGoalStore.shared
    ) {
        self.userDefaults = userDefaults
        self.cloudStore = cloudStore
    }

    func customGoalsStorageKey(for groupId: String?) -> String {
        let gid = groupId ?? ""
        return "ViewingCustomGoals.v3.\(gid)"
    }

    func loadYearlyGoals() {
        if let data = userDefaults.data(forKey: yearlyGoalsStorageKey),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            goalsByYear = decoded
        } else {
            goalsByYear = [:]
        }
    }

    func setYearlyTarget(_ target: Int, selectedYear: Int, groupId: String?) {
        let clamped = max(1, target)
        goalsByYear[selectedYear] = clamped
        persistYearlyGoals()
        Task { await syncYearlyGoalToCloud(year: selectedYear, target: clamped, groupId: groupId) }
    }

    func loadCustomGoals(groupId: String?) {
        let storageKey = customGoalsStorageKey(for: groupId)
        if let data = userDefaults.data(forKey: storageKey),
           let payload = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data) {
            customGoals = stableDedupe(payload.goals)
            return
        }

        customGoals = []
    }

    func upsertCustomGoal(_ goal: ViewingCustomGoal, groupId: String?) {
        var next = customGoals

        if let idx = next.firstIndex(where: { $0.id == goal.id }) {
            next[idx] = goal
        } else if let key = goal.uniqueKey, let idx = next.firstIndex(where: { $0.uniqueKey == key }) {
            var updatedGoal = goal
            updatedGoal.id = next[idx].id
            updatedGoal.createdAt = next[idx].createdAt
            next[idx] = updatedGoal
        } else {
            next.append(goal)
        }

        customGoals = stableDedupe(next)
        persistCustomGoals(groupId: groupId)
        Task { await syncCustomGoalsToCloud(groupId: groupId) }
    }

    func deleteCustomGoal(_ goal: ViewingCustomGoal, groupId: String?) {
        customGoals.removeAll { $0.id == goal.id }
        persistCustomGoals(groupId: groupId)
        Task { await syncCustomGoalsToCloud(groupId: groupId) }
    }

    func syncFromCloud(groupId: String?) async {
        syncCount += 1
        defer { syncCount -= 1 }

        do {
            let remoteYearly = try await cloudStore.fetchGoals(forGroupId: groupId)
            if !remoteYearly.isEmpty {
                goalsByYear = remoteYearly
                persistYearlyGoals()
            }

            let remoteCustom = try await cloudStore.fetchCustomGoals(forGroupId: groupId)
            if !remoteCustom.goals.isEmpty {
                customGoals = stableDedupe(remoteCustom.goals)
                persistCustomGoals(groupId: groupId)
            }
        } catch {
            print("CloudKit syncFromCloud error: \(error)")
        }
    }

    func sortedGoals(activeIn selectedYear: Int) -> [ViewingCustomGoal] {
        customGoals
            .filter { $0.isActive(in: selectedYear) }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type.rawValue < rhs.type.rawValue
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func stableDedupe(_ goals: [ViewingCustomGoal]) -> [ViewingCustomGoal] {
        var seen: Set<String> = []
        var out: [ViewingCustomGoal] = []
        out.reserveCapacity(goals.count)

        for goal in goals.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let key = goal.uniqueKey {
                if seen.contains(key) {
                    continue
                }
                seen.insert(key)
            }
            out.append(goal)
        }

        return out
    }

    private func persistYearlyGoals() {
        if let data = try? JSONEncoder().encode(goalsByYear) {
            userDefaults.set(data, forKey: yearlyGoalsStorageKey)
        }
    }

    private func persistCustomGoals(groupId: String?) {
        let payload = ViewingCustomGoalsPayload(version: 3, goals: stableDedupe(customGoals))
        if let data = try? JSONEncoder().encode(payload) {
            userDefaults.set(data, forKey: customGoalsStorageKey(for: groupId))
        }
    }

    private func syncYearlyGoalToCloud(year: Int, target: Int, groupId: String?) async {
        syncCount += 1
        defer { syncCount -= 1 }

        do {
            try await cloudStore.saveGoal(year: year, target: target, groupId: groupId)
        } catch {
            print("CloudKit save yearly goal error: \(error)")
        }
    }

    private func syncCustomGoalsToCloud(groupId: String?) async {
        syncCount += 1
        defer { syncCount -= 1 }

        do {
            let payload = ViewingCustomGoalsPayload(version: 3, goals: stableDedupe(customGoals))
            try await cloudStore.saveCustomGoals(payload, groupId: groupId)
        } catch {
            print("CloudKit save custom goals error: \(error)")
        }
    }
}
