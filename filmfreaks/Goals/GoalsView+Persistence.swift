//
//  GoalsView+Persistence.swift
//  filmfreaks
//
//  Local persistence + CloudKit sync for yearly goals and custom goals.
//

internal import SwiftUI

extension GoalsView {

    // MARK: - Yearly Goal Persist/Sync

    func yearOptions() -> [Int] {
        let cal = Calendar.current
        let current = cal.component(.year, from: Date())

        let yearsFromMovies: [Int] = movieStore.movies.compactMap { m in
            guard let d = m.watchedDate else { return nil }
            return cal.component(.year, from: d)
        }

        var set = Set<Int>(yearsFromMovies)
        set.formUnion(goalsByYear.keys)
        set.insert(current)
        set.insert(selectedYear)

        return Array(set).sorted(by: >)
    }

    func loadYearlyGoals() {
        if let data = UserDefaults.standard.data(forKey: yearlyGoalsStorageKey),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            goalsByYear = decoded
        } else {
            goalsByYear = [:]
        }
    }

    private func persistYearlyGoals() {
        if let data = try? JSONEncoder().encode(goalsByYear) {
            UserDefaults.standard.set(data, forKey: yearlyGoalsStorageKey)
        }
    }

    func setYearlyTarget(_ target: Int) {
        let clamped = max(1, target)
        goalsByYear[selectedYear] = clamped
        persistYearlyGoals()
        Task { await syncYearlyGoalToCloud(year: selectedYear, target: clamped) }
    }

    private func syncYearlyGoalToCloud(year: Int, target: Int) async {
        syncCount += 1
        defer { syncCount -= 1 }
        do {
            try await CloudKitGoalStore.shared.saveGoal(year: year, target: target, groupId: movieStore.currentGroupId)
        } catch {
            print("CloudKit save yearly goal error: \(error)")
        }
    }

    // MARK: - Custom Goals Persist/Sync

    func sortedCustomGoals() -> [ViewingCustomGoal] {
        customGoalsForSelectedYear.sorted { a, b in
            if a.type != b.type { return a.type.rawValue < b.type.rawValue }
            return a.createdAt < b.createdAt
        }
    }

    func loadCustomGoals() {
        // Local first
        if let data = UserDefaults.standard.data(forKey: customGoalsStorageKey),
           let payload = try? JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data) {
            customGoals = stableDedupe(payload.goals)
            return
        }
        customGoals = []
    }

    private func persistCustomGoals() {
        let payload = ViewingCustomGoalsPayload(version: 3, goals: stableDedupe(customGoals))
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: customGoalsStorageKey)
        }
    }

    func upsertCustomGoal(_ goal: ViewingCustomGoal) {
        var next = customGoals

        // Replace by ID (edit) OR by unique key (dedupe)
        if let idx = next.firstIndex(where: { $0.id == goal.id }) {
            next[idx] = goal
        } else if let key = goal.uniqueKey, let idx = next.firstIndex(where: { $0.uniqueKey == key }) {
            var g = goal
            // keep original ID for stability (links, sheets etc.)
            g.id = next[idx].id
            g.createdAt = next[idx].createdAt
            next[idx] = g
        } else {
            next.append(goal)
        }

        customGoals = stableDedupe(next)
        persistCustomGoals()
        Task { await syncCustomGoalsToCloud() }
    }

    func deleteCustomGoal(_ goal: ViewingCustomGoal) {
        customGoals.removeAll { $0.id == goal.id }
        persistCustomGoals()
        Task { await syncCustomGoalsToCloud() }
    }

    private func stableDedupe(_ goals: [ViewingCustomGoal]) -> [ViewingCustomGoal] {
        var seen: Set<String> = []
        var out: [ViewingCustomGoal] = []
        out.reserveCapacity(goals.count)

        for g in goals.sorted(by: { $0.createdAt < $1.createdAt }) {
            if let key = g.uniqueKey {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            out.append(g)
        }
        return out
    }

    private func syncCustomGoalsToCloud() async {
        syncCount += 1
        defer { syncCount -= 1 }
        do {
            let payload = ViewingCustomGoalsPayload(version: 3, goals: stableDedupe(customGoals))
            try await CloudKitGoalStore.shared.saveCustomGoals(payload, groupId: movieStore.currentGroupId)
        } catch {
            print("CloudKit save custom goals error: \(error)")
        }
    }

    func syncFromCloud() async {
        syncCount += 1
        defer { syncCount -= 1 }

        do {
            let remoteYearly = try await CloudKitGoalStore.shared.fetchGoals(forGroupId: movieStore.currentGroupId)
            if !remoteYearly.isEmpty {
                goalsByYear = remoteYearly
                persistYearlyGoals()
            }

            let remoteCustom = try await CloudKitGoalStore.shared.fetchCustomGoals(forGroupId: movieStore.currentGroupId)
            if !remoteCustom.goals.isEmpty {
                customGoals = stableDedupe(remoteCustom.goals)
                persistCustomGoals()
            }

        } catch {
            print("CloudKit syncFromCloud error: \(error)")
        }
    }
}
