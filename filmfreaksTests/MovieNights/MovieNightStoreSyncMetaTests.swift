import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieNightStoreSyncMetaTests {

    @Test func appendActivityKeepsLatestTwoHundredEntries() async throws {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-append-activity"

        for offset in 0..<205 {
            store.appendActivity(
                MovieNightActivityEvent(
                    groupId: groupId,
                    kind: .proposed,
                    createdAt: makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: offset),
                    eventId: UUID(),
                    eventStart: makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: offset),
                    actorUserId: UUID(),
                    actorName: "Marc",
                    decision: nil,
                    newStatus: .open,
                    note: nil
                ),
                groupId: groupId
            )
        }

        let activity = try #require(store.activityByGroup[groupId])
        #expect(activity.count == 200)
        #expect(activity.first?.createdAt == makeDate(year: 2026, month: 4, day: 1, hour: 12, minute: 5))
        #expect(activity.last?.createdAt == makeDate(year: 2026, month: 4, day: 1, hour: 15, minute: 24))
    }

    @Test func ensureSyncMetaLoadedHydratesValuesFromUserDefaultsOnce() async {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-sync-meta-\(UUID().uuidString)"
        let pendingKey = store.syncMetaKey(groupId, "pending")
        let lastAtKey = store.syncMetaKey(groupId, "lastAt")
        let lastErrorKey = store.syncMetaKey(groupId, "lastError")
        let expectedDate = makeDate(year: 2026, month: 4, day: 9, hour: 14)

        defer {
            UserDefaults.standard.removeObject(forKey: pendingKey)
            UserDefaults.standard.removeObject(forKey: lastAtKey)
            UserDefaults.standard.removeObject(forKey: lastErrorKey)
        }

        UserDefaults.standard.set(7, forKey: pendingKey)
        UserDefaults.standard.set(expectedDate, forKey: lastAtKey)
        UserDefaults.standard.set("offline", forKey: lastErrorKey)

        store.ensureSyncMetaLoaded(forGroupId: groupId)

        #expect(store.pendingCloudChangesByGroup[groupId] == 7)
        #expect(store.lastCloudSyncAtByGroup[groupId] == expectedDate)
        #expect(store.lastCloudSyncErrorByGroup[groupId] == "offline")

        UserDefaults.standard.set(3, forKey: pendingKey)
        store.ensureSyncMetaLoaded(forGroupId: groupId)

        #expect(store.pendingCloudChangesByGroup[groupId] == 7)
    }

    @Test func markCloudSyncSuccessClearsStoredErrorAndUpdatesLastSyncDate() async {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-sync-success-\(UUID().uuidString)"
        let lastErrorKey = store.syncMetaKey(groupId, "lastError")
        let lastAtKey = store.syncMetaKey(groupId, "lastAt")

        defer {
            UserDefaults.standard.removeObject(forKey: lastErrorKey)
            UserDefaults.standard.removeObject(forKey: lastAtKey)
        }

        store.lastCloudSyncErrorByGroup[groupId] = "old error"
        UserDefaults.standard.set("old error", forKey: lastErrorKey)

        store.markCloudSyncSuccess(forGroupId: groupId)

        #expect(store.lastCloudSyncErrorByGroup[groupId] == nil)
        #expect(UserDefaults.standard.string(forKey: lastErrorKey) == nil)
        #expect(store.lastCloudSyncAtByGroup[groupId] != nil)
        #expect(UserDefaults.standard.object(forKey: lastAtKey) as? Date != nil)
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
