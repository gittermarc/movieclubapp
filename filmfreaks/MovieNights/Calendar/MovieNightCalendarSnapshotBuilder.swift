import Foundation

struct MovieNightCalendarSnapshot: Equatable {
    var eventsInMonth: [MovieNightEvent] = []
    var eventsForSelectedDay: [MovieNightEvent] = []
}

enum MovieNightCalendarSnapshotBuilder {

    static func build(
        events: [MovieNightEvent],
        monthAnchor: Date,
        selectedDay: Date,
        calendar: Calendar = .current
    ) -> MovieNightCalendarSnapshot {
        let startOfMonth = calendar.startOfMonth(for: monthAnchor)
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth) ?? startOfMonth

        let eventsInMonth = events
            .filter {
                $0.proposedStart >= startOfMonth &&
                $0.proposedStart < endOfMonth &&
                $0.status != .cancelled
            }
            .sorted { $0.proposedStart < $1.proposedStart }

        let eventsForSelectedDay = eventsInMonth
            .filter { calendar.isDate($0.proposedStart, inSameDayAs: selectedDay) }
            .sorted { $0.proposedStart < $1.proposedStart }

        return MovieNightCalendarSnapshot(
            eventsInMonth: eventsInMonth,
            eventsForSelectedDay: eventsForSelectedDay
        )
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
