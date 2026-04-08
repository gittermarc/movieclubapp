//
//  GoalsView+Persistence.swift
//  filmfreaks
//
//  UI-facing bridges for local persistence + CloudKit sync backed by GoalsStore.
//

internal import SwiftUI

extension GoalsView {

    func yearOptions() -> [Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        let yearsFromMovies: [Int] = movieStore.movies.compactMap { movie in
            guard let watchedDate = movie.watchedDate else { return nil }
            return calendar.component(.year, from: watchedDate)
        }

        var years = Set<Int>(yearsFromMovies)
        years.formUnion(goalsStore.goalsByYear.keys)
        years.insert(currentYear)
        years.insert(selectedYear)

        return Array(years).sorted(by: >)
    }

    func sortedCustomGoals() -> [ViewingCustomGoal] {
        goalsStore.sortedGoals(activeIn: selectedYear)
    }

    func loadYearlyGoals() {
        goalsStore.loadYearlyGoals()
    }

    func loadCustomGoals() {
        goalsStore.loadCustomGoals(groupId: movieStore.currentGroupId)
    }

    func setYearlyTarget(_ target: Int) {
        goalsStore.setYearlyTarget(target, selectedYear: selectedYear, groupId: movieStore.currentGroupId)
    }

    func upsertCustomGoal(_ goal: ViewingCustomGoal) {
        goalsStore.upsertCustomGoal(goal, groupId: movieStore.currentGroupId)
    }

    func deleteCustomGoal(_ goal: ViewingCustomGoal) {
        goalsStore.deleteCustomGoal(goal, groupId: movieStore.currentGroupId)
    }

    func syncFromCloud() async {
        await goalsStore.syncFromCloud(groupId: movieStore.currentGroupId)
    }
}
