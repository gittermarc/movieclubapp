import Foundation
import Testing
@testable import filmfreaks

struct MovieNightStoreRetryHandlingTests {

    @Test func networkFlushDecisionOnlyTriggersOnOfflineToOnlineTransition() {
        #expect(MovieNightStore.shouldFlushPendingChangesOnNetworkTransition(from: false, to: true))
        #expect(MovieNightStore.shouldFlushPendingChangesOnNetworkTransition(from: true, to: true) == false)
        #expect(MovieNightStore.shouldFlushPendingChangesOnNetworkTransition(from: true, to: false) == false)
        #expect(MovieNightStore.shouldFlushPendingChangesOnNetworkTransition(from: false, to: false) == false)
    }

    @Test func groupContextRetryHonorsThrottleWindow() {
        let now = makeDate(year: 2026, month: 4, day: 9, hour: 14, minute: 0, second: 10)
        let insideWindow = makeDate(year: 2026, month: 4, day: 9, hour: 14, minute: 0, second: 9)
        let edgeOfWindow = makeDate(year: 2026, month: 4, day: 9, hour: 14, minute: 0, second: 8)
        let outsideWindow = makeDate(year: 2026, month: 4, day: 9, hour: 14, minute: 0, second: 7)

        #expect(MovieNightStore.shouldRetryGroupContext(lastAttemptAt: nil, now: now, minRetryInterval: 2))
        #expect(MovieNightStore.shouldRetryGroupContext(lastAttemptAt: insideWindow, now: now, minRetryInterval: 2) == false)
        #expect(MovieNightStore.shouldRetryGroupContext(lastAttemptAt: edgeOfWindow, now: now, minRetryInterval: 2))
        #expect(MovieNightStore.shouldRetryGroupContext(lastAttemptAt: outsideWindow, now: now, minRetryInterval: 2))
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
