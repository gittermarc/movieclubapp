//
//  GoalsView+Matching.swift
//  filmfreaks
//
//  Matching logic for custom goals.
//

internal import SwiftUI

extension GoalsView {

    // MARK: - Matching Logic

    func matchingMovies(for goal: ViewingCustomGoal) -> [Movie] {
        let list = moviesInSelectedYear

        switch goal.rule {
        case .releaseDecade(let decadeStart):
            let minYear = decadeStart
            let maxYear = decadeStart + 9
            return list.filter { m in
                guard let y = Int(m.year) else { return false }
                return y >= minYear && y <= maxYear
            }

        case .person(let id, _, _):
            guard id > 0 else { return [] }
            return list.filter { m in
                (m.cast ?? []).contains(where: { $0.personId == id })
            }

        case .director(let id, _, _):
            guard id > 0 else { return [] }
            return list.filter { m in
                (m.directors ?? []).contains(where: { $0.personId == id })
            }

        case .genre(let id, let name):
            let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if id > 0 {
                return list.filter { m in
                    if let ids = m.genreIds, ids.contains(id) { return true }
                    return (m.genres ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            } else {
                return list.filter { m in
                    (m.genres ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            }

        case .keyword(let id, let name):
            let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if id > 0 {
                return list.filter { m in
                    if let ids = m.keywordIds, ids.contains(id) { return true }
                    return (m.keywords ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            } else {
                return list.filter { m in
                    (m.keywords ?? []).contains(where: { $0.lowercased() == lowerName })
                }
            }
        }
    }
}
