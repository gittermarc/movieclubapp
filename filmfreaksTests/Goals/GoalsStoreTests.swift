import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct GoalsStoreTests {

    @Test func loadsYearlyGoalsFromGroupScopedLocalStorage() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.yearly")
        let expected = [2026: 42]
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())

        suite.defaults.set(
            try JSONEncoder().encode(expected),
            forKey: store.yearlyGoalsStorageKey(for: "group-a")
        )

        store.loadYearlyGoals(groupId: "group-a")

        #expect(store.goalsByYear == expected)
    }

    @Test func setYearlyTargetPersistsClampedValueInGroupScopedStorage() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.clamp")
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())

        store.setYearlyTarget(0, selectedYear: 2026, groupId: "group-a")

        #expect(store.goalsByYear[2026] == 1)

        let data = try #require(suite.defaults.data(forKey: store.yearlyGoalsStorageKey(for: "group-a")))
        let decoded = try JSONDecoder().decode([Int: Int].self, from: data)
        #expect(decoded[2026] == 1)
        #expect(suite.defaults.data(forKey: store.legacyYearlyGoalsStorageKey) == nil)
    }

    @Test func yearlyGoalsAreSeparatedByGroup() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.yearlyGroups")
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())

        suite.defaults.set(
            try JSONEncoder().encode([2026: 12]),
            forKey: store.yearlyGoalsStorageKey(for: "group-a")
        )
        suite.defaults.set(
            try JSONEncoder().encode([2026: 34]),
            forKey: store.yearlyGoalsStorageKey(for: "group-b")
        )

        store.loadYearlyGoals(groupId: "group-a")
        #expect(store.goalsByYear == [2026: 12])

        store.loadYearlyGoals(groupId: "group-b")
        #expect(store.goalsByYear == [2026: 34])
    }

    @Test func migratesLegacyYearlyGoalsOnlyOnceWithoutDeletingLegacyData() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.legacyMigration")
        let legacy = [2026: 42]
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())

        suite.defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: store.legacyYearlyGoalsStorageKey
        )

        store.loadYearlyGoals(groupId: "group-a")

        #expect(store.goalsByYear == legacy)
        #expect(suite.defaults.data(forKey: store.legacyYearlyGoalsStorageKey) != nil)

        let migratedData = try #require(suite.defaults.data(forKey: store.yearlyGoalsStorageKey(for: "group-a")))
        let migrated = try JSONDecoder().decode([Int: Int].self, from: migratedData)
        #expect(migrated == legacy)

        store.loadYearlyGoals(groupId: "group-b")
        #expect(store.goalsByYear == [:])
        #expect(suite.defaults.data(forKey: store.yearlyGoalsStorageKey(for: "group-b")) == nil)
    }

    @Test func loadCustomGoalsUsesGroupSpecificStorageKey() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.groups")
        let groupA = ViewingCustomGoalsPayload(goals: [makeDecadeGoal(decade: 1980, startYear: 2026)])
        let groupB = ViewingCustomGoalsPayload(goals: [makeDecadeGoal(decade: 1990, startYear: 2026)])

        suite.defaults.set(
            try JSONEncoder().encode(groupA),
            forKey: "ViewingCustomGoals.v3.group-a"
        )
        suite.defaults.set(
            try JSONEncoder().encode(groupB),
            forKey: "ViewingCustomGoals.v3.group-b"
        )

        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())
        store.loadCustomGoals(groupId: "group-a")
        #expect(store.customGoals.map(\.uniqueKey) == groupA.goals.map(\.uniqueKey))

        store.loadCustomGoals(groupId: "group-b")
        #expect(store.customGoals.map(\.uniqueKey) == groupB.goals.map(\.uniqueKey))
    }

    @Test func upsertCustomGoalReplacesMatchingUniqueKeyButKeepsIdentity() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.upsert")
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())
        let originalId = UUID()
        let createdAt = Date(timeIntervalSince1970: 10)

        store.upsertCustomGoal(
            ViewingCustomGoal(
                id: originalId,
                type: .director,
                rule: .director(id: 7, name: "Old Name", profilePath: nil),
                target: 5,
                createdAt: createdAt,
                startYear: 2026,
                durationYears: 1
            ),
            groupId: "group-a"
        )

        store.upsertCustomGoal(
            ViewingCustomGoal(
                type: .director,
                rule: .director(id: 7, name: "New Name", profilePath: nil),
                target: 9,
                createdAt: Date(timeIntervalSince1970: 500),
                startYear: 2026,
                durationYears: 1
            ),
            groupId: "group-a"
        )

        #expect(store.customGoals.count == 1)
        #expect(store.customGoals[0].id == originalId)
        #expect(store.customGoals[0].createdAt == createdAt)
        #expect(store.customGoals[0].target == 9)

        let data = try #require(suite.defaults.data(forKey: store.customGoalsStorageKey(for: "group-a")))
        let payload = try JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data)
        #expect(payload.goals.count == 1)
        #expect(payload.goals[0].id == originalId)
    }

    @Test func deleteCustomGoalRemovesById() throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.delete")
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: GoalsCloudStoreMock())
        let first = makeDecadeGoal(decade: 1980, startYear: 2026)
        let second = makeDecadeGoal(decade: 1990, startYear: 2026)

        store.upsertCustomGoal(first, groupId: "group-a")
        store.upsertCustomGoal(second, groupId: "group-a")
        store.deleteCustomGoal(first, groupId: "group-a")

        #expect(store.customGoals.map(\.id) == [second.id])
    }

    @Test func syncFromCloudAppliesEmptyRemotePayloads() async throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.emptyRemote")
        let remote = GoalsCloudStoreMock()
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: remote)
        let localGoal = makeDecadeGoal(decade: 1980, startYear: 2026)

        suite.defaults.set(
            try JSONEncoder().encode([2026: 23]),
            forKey: store.yearlyGoalsStorageKey(for: "group-a")
        )
        suite.defaults.set(
            try JSONEncoder().encode(ViewingCustomGoalsPayload(goals: [localGoal])),
            forKey: store.customGoalsStorageKey(for: "group-a")
        )
        store.loadYearlyGoals(groupId: "group-a")
        store.loadCustomGoals(groupId: "group-a")

        await store.syncFromCloud(groupId: "group-a")

        #expect(store.goalsByYear == [:])
        #expect(store.customGoals == [])

        let yearlyData = try #require(suite.defaults.data(forKey: store.yearlyGoalsStorageKey(for: "group-a")))
        let yearly = try JSONDecoder().decode([Int: Int].self, from: yearlyData)
        #expect(yearly == [:])

        let customData = try #require(suite.defaults.data(forKey: store.customGoalsStorageKey(for: "group-a")))
        let custom = try JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: customData)
        #expect(custom.goals == [])
    }

    @Test func emptyRemoteYearlyGoalsPreventLegacyZombieRehydration() async throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.emptyRemoteLegacy")
        let legacy = [2026: 42]
        let remote = GoalsCloudStoreMock()
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: remote)

        suite.defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: store.legacyYearlyGoalsStorageKey
        )

        store.loadYearlyGoals(groupId: "group-a")
        #expect(store.goalsByYear == legacy)

        await store.syncFromCloud(groupId: "group-a")
        #expect(store.goalsByYear == [:])

        let reloadedStore = GoalsStore(userDefaults: suite.defaults, cloudStore: remote)
        reloadedStore.loadYearlyGoals(groupId: "group-a")
        #expect(reloadedStore.goalsByYear == [:])
    }

    @Test func syncFromCloudPersistsStableDedupeForRemoteCustomGoals() async throws {
        let suite = try TestUserDefaultsSuite(prefix: "GoalsStoreTests.remoteMerge")
        let createdAt = Date(timeIntervalSince1970: 100)
        let first = ViewingCustomGoal(
            id: UUID(),
            type: .genre,
            rule: .genre(id: 12, name: "Adventure"),
            target: 3,
            createdAt: createdAt,
            startYear: 2026,
            durationYears: 1
        )
        let duplicate = ViewingCustomGoal(
            id: UUID(),
            type: .genre,
            rule: .genre(id: 12, name: "Adventure"),
            target: 9,
            createdAt: Date(timeIntervalSince1970: 300),
            startYear: 2026,
            durationYears: 1
        )
        let remote = GoalsCloudStoreMock(
            remoteYearly: [2026: 15],
            remoteCustom: ViewingCustomGoalsPayload(goals: [duplicate, first])
        )
        let store = GoalsStore(userDefaults: suite.defaults, cloudStore: remote)

        await store.syncFromCloud(groupId: "group-a")

        #expect(store.goalsByYear[2026] == 15)
        #expect(store.customGoals.count == 1)
        #expect(store.customGoals[0].id == first.id)
        #expect(store.customGoals[0].target == first.target)

        let yearlyData = try #require(suite.defaults.data(forKey: store.yearlyGoalsStorageKey(for: "group-a")))
        let yearly = try JSONDecoder().decode([Int: Int].self, from: yearlyData)
        #expect(yearly[2026] == 15)

        let data = try #require(suite.defaults.data(forKey: store.customGoalsStorageKey(for: "group-a")))
        let payload = try JSONDecoder().decode(ViewingCustomGoalsPayload.self, from: data)
        #expect(payload.goals.count == 1)
        #expect(payload.goals[0].id == first.id)
    }

    private func makeDecadeGoal(decade: Int, startYear: Int) -> ViewingCustomGoal {
        ViewingCustomGoal(
            type: .decade,
            rule: .releaseDecade(decade),
            target: 5,
            createdAt: Date(timeIntervalSince1970: TimeInterval(decade)),
            startYear: startYear,
            durationYears: 1
        )
    }
}

private final class GoalsCloudStoreMock: GoalsCloudSyncing {
    var remoteYearly: [Int: Int]
    var remoteCustom: ViewingCustomGoalsPayload
    var savedYearlyCalls: [(year: Int, target: Int, groupId: String?)] = []
    var savedCustomPayloads: [(payload: ViewingCustomGoalsPayload, groupId: String?)] = []

    init(
        remoteYearly: [Int: Int] = [:],
        remoteCustom: ViewingCustomGoalsPayload = ViewingCustomGoalsPayload()
    ) {
        self.remoteYearly = remoteYearly
        self.remoteCustom = remoteCustom
    }

    func fetchGoals(forGroupId groupId: String?) async throws -> [Int: Int] {
        remoteYearly
    }

    func saveGoal(year: Int, target: Int, groupId: String?) async throws {
        savedYearlyCalls.append((year, target, groupId))
    }

    func fetchCustomGoals(forGroupId groupId: String?) async throws -> ViewingCustomGoalsPayload {
        remoteCustom
    }

    func saveCustomGoals(_ payload: ViewingCustomGoalsPayload, groupId: String?) async throws {
        savedCustomPayloads.append((payload, groupId))
    }
}
