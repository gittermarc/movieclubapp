import Foundation
import Testing
@testable import filmfreaks

struct ContentActivitySessionStateStoreTests {

    @Test func usesPreviousLaunchAsBaselineForUnseenThreshold() throws {
        let suite = try TestUserDefaultsSuite(prefix: "group-activity-session")
        let firstLaunch = makeDate(day: 10, hour: 8)
        let secondLaunch = makeDate(day: 11, hour: 9)

        GroupActivitySessionStateStore.registerAppLaunch(now: firstLaunch, defaults: suite.defaults)
        GroupActivitySessionStateStore.registerAppLaunch(now: secondLaunch, defaults: suite.defaults)

        let threshold = GroupActivitySessionStateStore.unseenThreshold(
            groupId: "group-1",
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            userName: "Marc",
            defaults: suite.defaults
        )

        #expect(threshold == firstLaunch)
    }

    @Test func markViewedWinsOverPreviousLaunchForSameGroupAndUser() throws {
        let suite = try TestUserDefaultsSuite(prefix: "group-activity-session")
        let firstLaunch = makeDate(day: 10, hour: 8)
        let secondLaunch = makeDate(day: 11, hour: 9)
        let viewedAt = makeDate(day: 11, hour: 10)

        GroupActivitySessionStateStore.registerAppLaunch(now: firstLaunch, defaults: suite.defaults)
        GroupActivitySessionStateStore.registerAppLaunch(now: secondLaunch, defaults: suite.defaults)
        GroupActivitySessionStateStore.markViewed(
            groupId: "group-1",
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            userName: "Marc",
            viewedAt: viewedAt,
            defaults: suite.defaults
        )

        let threshold = GroupActivitySessionStateStore.unseenThreshold(
            groupId: "group-1",
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            userName: "Marc",
            defaults: suite.defaults
        )

        #expect(threshold == viewedAt)
    }

    @Test func keepsViewedStateScopedPerGroupAndUser() throws {
        let suite = try TestUserDefaultsSuite(prefix: "group-activity-session")
        let firstLaunch = makeDate(day: 10, hour: 8)
        let secondLaunch = makeDate(day: 11, hour: 9)
        let viewedAt = makeDate(day: 11, hour: 10)

        GroupActivitySessionStateStore.registerAppLaunch(now: firstLaunch, defaults: suite.defaults)
        GroupActivitySessionStateStore.registerAppLaunch(now: secondLaunch, defaults: suite.defaults)
        GroupActivitySessionStateStore.markViewed(
            groupId: "group-1",
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            userName: "Marc",
            viewedAt: viewedAt,
            defaults: suite.defaults
        )

        let otherGroupThreshold = GroupActivitySessionStateStore.unseenThreshold(
            groupId: "group-2",
            userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            userName: "Marc",
            defaults: suite.defaults
        )
        let otherUserThreshold = GroupActivitySessionStateStore.unseenThreshold(
            groupId: "group-1",
            userId: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
            userName: "Michi",
            defaults: suite.defaults
        )

        #expect(otherGroupThreshold == firstLaunch)
        #expect(otherUserThreshold == firstLaunch)
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: day,
            hour: hour,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
