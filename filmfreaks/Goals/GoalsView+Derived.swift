//
//  GoalsView+Derived.swift
//  filmfreaks
//
//  Derived state + lightweight helpers for GoalsView.
//

internal import SwiftUI

extension GoalsView {

    // MARK: - Derived Data

    var moviesInSelectedYear: [Movie] {
        let cal = Calendar.current
        return movieStore.movies
            .compactMap { m in
                guard let d = m.watchedDate else { return nil }
                return cal.component(.year, from: d) == selectedYear ? m : nil
            }
            .sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    var customGoalsForSelectedYear: [ViewingCustomGoal] {
        goalsStore.customGoals.filter { $0.isActive(in: selectedYear) }
    }

    var yearlyTarget: Int {
        goalsStore.goalsByYear[selectedYear] ?? goalsStore.defaultYearlyGoal
    }

    var yearlyProgress: Double {
        guard yearlyTarget > 0 else { return 0 }
        return min(1.0, Double(moviesInSelectedYear.count) / Double(yearlyTarget))
    }

    var isSyncingGoals: Bool {
        goalsStore.isSyncingGoals
    }

    var availableDecades: [Int] {
        // Von vorhandenen Filmen ableiten, fallback: 1930–2020
        let years = movieStore.movies.compactMap { Int($0.year) }
        let minY = years.min() ?? 1930
        let maxY = years.max() ?? 2020
        let start = (minY / 10) * 10
        let end = (maxY / 10) * 10
        return stride(from: start, through: end, by: 10).map { $0 }.sorted()
    }

    var actorSuggestions: [PersonSuggestion] {
        var map: [Int: (name: String, count: Int, profilePath: String?)] = [:]

        for m in moviesInSelectedYear {
            guard let cast = m.cast else { continue }
            for c in cast {
                guard c.personId > 0 else { continue }
                let current = map[c.personId]
                map[c.personId] = (name: c.name, count: (current?.count ?? 0) + 1, profilePath: current?.profilePath)
            }
        }

        return map
            .map { PersonSuggestion(personId: $0.key, name: $0.value.name, count: $0.value.count, profilePath: $0.value.profilePath) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            .prefix(20)
            .map { $0 }
    }

    var directorSuggestions: [PersonSuggestion] {
        var map: [Int: (name: String, count: Int, profilePath: String?)] = [:]

        for m in moviesInSelectedYear {
            guard let directors = m.directors else { continue }
            for d in directors {
                guard d.personId > 0 else { continue }
                let current = map[d.personId]
                map[d.personId] = (name: d.name, count: (current?.count ?? 0) + 1, profilePath: current?.profilePath)
            }
        }

        return map
            .map { PersonSuggestion(personId: $0.key, name: $0.value.name, count: $0.value.count, profilePath: $0.value.profilePath) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            .prefix(20)
            .map { $0 }
    }
}
