import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieNightStoreMergeTests {

    @Test func mergeEventsPrefersNewerRemoteVersionsAndAppliesDeletes() async {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-merge-events"
        let eventId = UUID()
        let olderLocal = makeEvent(
            id: eventId,
            groupId: groupId,
            proposedStart: makeDate(year: 2026, month: 4, day: 14, hour: 20),
            updatedAt: makeDate(year: 2026, month: 4, day: 1, hour: 10),
            note: "local"
        )
        let otherEvent = makeEvent(
            id: UUID(),
            groupId: groupId,
            proposedStart: makeDate(year: 2026, month: 4, day: 20, hour: 20),
            updatedAt: makeDate(year: 2026, month: 4, day: 1, hour: 11),
            note: "delete me"
        )

        store.eventsByGroup[groupId] = [otherEvent, olderLocal]

        let newerRemote = makeEvent(
            id: eventId,
            groupId: groupId,
            proposedStart: makeDate(year: 2026, month: 4, day: 12, hour: 20),
            updatedAt: makeDate(year: 2026, month: 4, day: 2, hour: 9),
            note: "remote"
        )

        store.mergeEvents([newerRemote], deleted: [otherEvent.id], groupId: groupId)

        #expect(store.eventsByGroup[groupId] == [newerRemote])
    }

    @Test func mergeResponsesKeepsNewestResponsePerCompositeId() async {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-merge-responses"
        let eventId = UUID()
        let userId = UUID()

        let local = MovieNightResponse(
            eventId: eventId,
            userId: userId,
            userName: "Marc",
            decision: .accepted,
            respondedAt: makeDate(year: 2026, month: 4, day: 2, hour: 10)
        )
        let staleRemote = MovieNightResponse(
            eventId: eventId,
            userId: userId,
            userName: "Marc Alt",
            decision: .declined,
            respondedAt: makeDate(year: 2026, month: 4, day: 1, hour: 10)
        )

        store.responsesByGroup[groupId] = [local]
        store.mergeResponses([staleRemote], deleted: [], groupId: groupId)

        #expect(store.responsesByGroup[groupId] == [local])
    }

    @Test func mergeActivitySortsNewestFirstAndCapsToTwoHundredItems() async throws {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-merge-activity"
        let changed = (0..<205).map { offset in
            makeActivity(
                id: UUID(),
                groupId: groupId,
                createdAt: makeDate(year: 2026, month: 4, day: 1, hour: 0, minute: offset)
            )
        }

        store.mergeActivity(changed, deleted: [], groupId: groupId)

        let merged = try #require(store.activityByGroup[groupId])
        #expect(merged.count == 200)
        #expect(merged.first?.createdAt == changed.max(by: { $0.createdAt < $1.createdAt })?.createdAt)
        #expect(merged.last?.createdAt == changed.sorted(by: { $0.createdAt > $1.createdAt })[199].createdAt)
    }

    private func makeEvent(
        id: UUID,
        groupId: String,
        proposedStart: Date,
        updatedAt: Date,
        note: String?
    ) -> MovieNightEvent {
        MovieNightEvent(
            id: id,
            groupId: groupId,
            proposedStart: proposedStart,
            createdAt: makeDate(year: 2026, month: 4, day: 1, hour: 9),
            updatedAt: updatedAt,
            proposerUserId: UUID(),
            proposerName: "Marc",
            note: note,
            status: .open
        )
    }

    private func makeActivity(id: UUID, groupId: String, createdAt: Date) -> MovieNightActivityEvent {
        MovieNightActivityEvent(
            id: id,
            groupId: groupId,
            kind: .responded,
            createdAt: createdAt,
            eventId: UUID(),
            eventStart: createdAt,
            actorUserId: UUID(),
            actorName: "Marc",
            decision: .accepted,
            newStatus: nil,
            note: nil
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
