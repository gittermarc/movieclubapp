import Foundation

struct TimelineMonthGroup: Equatable {
    let monthStart: Date
    let movies: [Movie]
}

struct TimelineSnapshot: Equatable {
    var availableYears: [Int] = []
    var filteredMovies: [Movie] = []
    var monthGroups: [TimelineMonthGroup] = []
}

enum TimelineSnapshotBuilder {

    static func build(
        movies: [Movie],
        filterMode: TimelineFilterMode,
        selectedRange: TimelineTimeRange,
        selectedYear: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> TimelineSnapshot {
        let watchedMovies = movies.filter { $0.watchedDate != nil }
        let availableYears = buildAvailableYears(from: watchedMovies, today: today, calendar: calendar)
        let filteredMovies = buildFilteredMovies(
            from: watchedMovies,
            filterMode: filterMode,
            selectedRange: selectedRange,
            selectedYear: selectedYear,
            today: today,
            calendar: calendar
        )
        let monthGroups = buildMonthGroups(from: filteredMovies, calendar: calendar)

        return TimelineSnapshot(
            availableYears: availableYears,
            filteredMovies: filteredMovies,
            monthGroups: monthGroups
        )
    }

    private static func buildAvailableYears(
        from movies: [Movie],
        today: Date,
        calendar: Calendar
    ) -> [Int] {
        let years = movies.compactMap { movie -> Int? in
            guard let watchedDate = movie.watchedDate else {
                return nil
            }
            return calendar.component(.year, from: watchedDate)
        }

        let currentYear = calendar.component(.year, from: today)
        return Array(Set(years + [currentYear])).sorted(by: >)
    }

    private static func buildFilteredMovies(
        from movies: [Movie],
        filterMode: TimelineFilterMode,
        selectedRange: TimelineTimeRange,
        selectedYear: Int,
        today: Date,
        calendar: Calendar
    ) -> [Movie] {
        let filtered = movies.filter { movie in
            guard let watchedDate = movie.watchedDate else {
                return false
            }

            switch filterMode {
            case .year:
                return calendar.component(.year, from: watchedDate) == selectedYear
            case .range:
                switch selectedRange {
                case .all:
                    return true
                case .thisYear:
                    return calendar.isDate(watchedDate, equalTo: today, toGranularity: .year)
                case .last30:
                    guard let fromDate = calendar.date(byAdding: .day, value: -30, to: today) else {
                        return false
                    }
                    return watchedDate >= fromDate
                case .last90:
                    guard let fromDate = calendar.date(byAdding: .day, value: -90, to: today) else {
                        return false
                    }
                    return watchedDate >= fromDate
                }
            }
        }

        return filtered.sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    private static func buildMonthGroups(
        from movies: [Movie],
        calendar: Calendar
    ) -> [TimelineMonthGroup] {
        var groupedMovies: [Date: [Movie]] = [:]

        for movie in movies {
            guard let watchedDate = movie.watchedDate else {
                continue
            }

            let components = calendar.dateComponents([.year, .month], from: watchedDate)
            guard let monthStart = calendar.date(from: components) else {
                continue
            }

            groupedMovies[monthStart, default: []].append(movie)
        }

        return groupedMovies
            .map { monthStart, movies in
                TimelineMonthGroup(
                    monthStart: monthStart,
                    movies: movies.sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
                )
            }
            .sorted { $0.monthStart > $1.monthStart }
    }
}
