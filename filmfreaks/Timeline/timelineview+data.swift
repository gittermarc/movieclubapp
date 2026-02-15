//
//  timelineview+data.swift
//  filmfreaks
//

internal import SwiftUI

extension TimelineView {

    var availableYears: [Int] {
        let cal = Calendar.current
        let years = movieStore.movies.compactMap { movie -> Int? in
            guard let d = movie.watchedDate else { return nil }
            return cal.component(.year, from: d)
        }

        let current = cal.component(.year, from: Date())
        return Array(Set(years + [current])).sorted(by: >)
    }

    var filteredMovies: [Movie] {
        let cal = Calendar.current
        let today = Date()

        let watched = movieStore.movies.compactMap { movie -> Movie? in
            guard movie.watchedDate != nil else { return nil }
            return movie
        }

        let filtered: [Movie] = watched.filter { movie in
            guard let date = movie.watchedDate else { return false }

            switch filterMode {
            case .year:
                return cal.component(.year, from: date) == selectedYear

            case .range:
                switch selectedRange {
                case .all:
                    return true
                case .thisYear:
                    return cal.isDate(date, equalTo: today, toGranularity: .year)
                case .last30:
                    if let from = cal.date(byAdding: .day, value: -30, to: today) {
                        return date >= from
                    }
                    return false
                case .last90:
                    if let from = cal.date(byAdding: .day, value: -90, to: today) {
                        return date >= from
                    }
                    return false
                }
            }
        }

        return filtered.sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    var monthGroups: [(monthStart: Date, movies: [Movie])] {
        let cal = Calendar.current
        var dict: [Date: [Movie]] = [:]

        for movie in filteredMovies {
            guard let d = movie.watchedDate else { continue }
            let comps = cal.dateComponents([.year, .month], from: d)
            if let monthStart = cal.date(from: comps) {
                dict[monthStart, default: []].append(movie)
            }
        }

        return dict
            .map { key, value in
                let sorted = value.sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
                return (monthStart: key, movies: sorted)
            }
            .sorted { $0.monthStart > $1.monthStart }
    }

    var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "LLLL yyyy"
        return df
    }

    func binding(for movie: Movie) -> Binding<Movie>? {
        guard let idx = movieStore.movies.firstIndex(where: { $0.id == movie.id }) else {
            return nil
        }
        return $movieStore.movies[idx]
    }
}
