import Foundation
import Testing
@testable import filmfreaks

struct MovieNightCalendarSnapshotBuilderTests {

    @Test func filtersCancelledEventsOutOfMonthSnapshot() {
        let calendar = makeCalendar()
        let monthAnchor = makeDate(year: 2026, month: 4, day: 15, hour: 12, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0, calendar: calendar)

        let snapshot = MovieNightCalendarSnapshotBuilder.build(
            events: [
                makeEvent(day: 10, hour: 20, status: .open, calendar: calendar),
                makeEvent(day: 11, hour: 20, status: .cancelled, calendar: calendar),
                makeEvent(year: 2026, month: 5, day: 10, hour: 20, status: .open, calendar: calendar)
            ],
            monthAnchor: monthAnchor,
            selectedDay: selectedDay,
            calendar: calendar
        )

        #expect(snapshot.eventsInMonth.count == 1)
        #expect(snapshot.eventsInMonth.map(\.status) == [.open])
    }

    @Test func monthSnapshotContainsOnlyEventsInsideMonth() {
        let calendar = makeCalendar()
        let monthAnchor = makeDate(year: 2026, month: 4, day: 5, hour: 12, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0, calendar: calendar)

        let snapshot = MovieNightCalendarSnapshotBuilder.build(
            events: [
                makeEvent(year: 2026, month: 3, day: 31, hour: 20, status: .open, calendar: calendar),
                makeEvent(year: 2026, month: 4, day: 1, hour: 20, status: .open, calendar: calendar),
                makeEvent(year: 2026, month: 4, day: 30, hour: 20, status: .scheduled, calendar: calendar),
                makeEvent(year: 2026, month: 5, day: 1, hour: 20, status: .open, calendar: calendar)
            ],
            monthAnchor: monthAnchor,
            selectedDay: selectedDay,
            calendar: calendar
        )

        #expect(snapshot.eventsInMonth.count == 2)
        #expect(snapshot.eventsInMonth.map { calendar.component(.month, from: $0.proposedStart) } == [4, 4])
    }

    @Test func selectedDaySnapshotContainsOnlySameDayEvents() {
        let calendar = makeCalendar()
        let monthAnchor = makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0, calendar: calendar)

        let snapshot = MovieNightCalendarSnapshotBuilder.build(
            events: [
                makeEvent(day: 10, hour: 18, status: .open, calendar: calendar),
                makeEvent(day: 10, hour: 20, status: .scheduled, calendar: calendar),
                makeEvent(day: 11, hour: 20, status: .open, calendar: calendar)
            ],
            monthAnchor: monthAnchor,
            selectedDay: selectedDay,
            calendar: calendar
        )

        #expect(snapshot.eventsForSelectedDay.count == 2)
        #expect(snapshot.eventsForSelectedDay.allSatisfy { calendar.isDate($0.proposedStart, inSameDayAs: selectedDay) })
    }

    @Test func selectedDayEventsAreSortedAscendingByStart() {
        let calendar = makeCalendar()
        let monthAnchor = makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0, calendar: calendar)

        let snapshot = MovieNightCalendarSnapshotBuilder.build(
            events: [
                makeEvent(day: 10, hour: 22, status: .open, calendar: calendar),
                makeEvent(day: 10, hour: 18, status: .open, calendar: calendar),
                makeEvent(day: 10, hour: 20, status: .open, calendar: calendar)
            ],
            monthAnchor: monthAnchor,
            selectedDay: selectedDay,
            calendar: calendar
        )

        #expect(snapshot.eventsForSelectedDay.map { calendar.component(.hour, from: $0.proposedStart) } == [18, 20, 22])
    }

    @Test func emptyMonthProducesEmptyLists() {
        let calendar = makeCalendar()
        let monthAnchor = makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 0, calendar: calendar)
        let selectedDay = makeDate(year: 2026, month: 4, day: 10, hour: 12, minute: 0, calendar: calendar)

        let snapshot = MovieNightCalendarSnapshotBuilder.build(
            events: [
                makeEvent(year: 2026, month: 5, day: 10, hour: 20, status: .open, calendar: calendar)
            ],
            monthAnchor: monthAnchor,
            selectedDay: selectedDay,
            calendar: calendar
        )

        #expect(snapshot.eventsInMonth.isEmpty)
        #expect(snapshot.eventsForSelectedDay.isEmpty)
    }

    private func makeEvent(
        year: Int = 2026,
        month: Int = 4,
        day: Int,
        hour: Int,
        status: MovieNightEvent.Status,
        calendar: Calendar
    ) -> MovieNightEvent {
        MovieNightEvent(
            groupId: "group-1",
            proposedStart: makeDate(year: year, month: month, day: day, hour: hour, minute: 0, calendar: calendar),
            createdAt: makeDate(year: year, month: month, day: day, hour: 8, minute: 0, calendar: calendar),
            updatedAt: makeDate(year: year, month: month, day: day, hour: 9, minute: 0, calendar: calendar),
            proposerUserId: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            proposerName: "Marc",
            suggestedMovie: nil,
            note: nil,
            status: status
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
