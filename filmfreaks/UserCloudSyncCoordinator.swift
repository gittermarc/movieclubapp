//
//  UserCloudSyncCoordinator.swift
//  filmfreaks
//
//  Debounced, durable CloudKit writer for GroupMember changes.
//

import Foundation

@MainActor
final class UserCloudSyncCoordinator {

    private struct PendingUpsert {
        let member: User
        let token: UUID
    }

    private struct PendingDelete {
        let token: UUID
    }

    private struct PendingGroupChanges {
        var upserts: [UUID: PendingUpsert] = [:]
        var deletes: [UUID: PendingDelete] = [:]

        var count: Int {
            upserts.count + deletes.count
        }

        var isEmpty: Bool {
            upserts.isEmpty && deletes.isEmpty
        }
    }

    private let cloudStore: CloudKitUserStore
    private let avatarDataProvider: (UUID, String) -> Data?
    private let beginSync: () -> Void
    private let endSync: () -> Void
    private let networkIsAvailable: () -> Bool
    private let pendingCountDidChange: (_ count: Int, _ groupId: String) -> Void
    private let batchDidSucceed: (_ groupId: String) -> Void
    private let batchDidFail: (_ error: Error, _ groupId: String) -> Void
    private let dirtyJournal: MemberCloudDirtyJournal
    private let debounceNanoseconds: UInt64

    private var changesByGroup: [String: PendingGroupChanges] = [:]
    private var flushingGroupIds = Set<String>()
    private var scheduledFlush: Task<Void, Never>?

    init(
        cloudStore: CloudKitUserStore,
        debounce: TimeInterval = 0.6,
        avatarDataProvider: @escaping (UUID, String) -> Data?,
        beginSync: @escaping () -> Void,
        endSync: @escaping () -> Void,
        networkIsAvailable: @escaping () -> Bool,
        pendingCountDidChange: @escaping (_ count: Int, _ groupId: String) -> Void,
        batchDidSucceed: @escaping (_ groupId: String) -> Void,
        batchDidFail: @escaping (_ error: Error, _ groupId: String) -> Void,
        dirtyJournal: MemberCloudDirtyJournal? = nil
    ) {
        self.cloudStore = cloudStore
        self.avatarDataProvider = avatarDataProvider
        self.beginSync = beginSync
        self.endSync = endSync
        self.networkIsAvailable = networkIsAvailable
        self.pendingCountDidChange = pendingCountDidChange
        self.batchDidSucceed = batchDidSucceed
        self.batchDidFail = batchDidFail
        self.dirtyJournal = dirtyJournal ?? .shared

        let nanoseconds = max(0.05, debounce) * 1_000_000_000
        self.debounceNanoseconds = UInt64(nanoseconds)
    }

    func queueUpsert(member: User, groupId: String) {
        let token = UUID()
        dirtyJournal.recordUpsert(member: member, groupId: groupId, token: token)

        var changes = changesByGroup[groupId] ?? PendingGroupChanges()
        changes.upserts[member.id] = PendingUpsert(member: member, token: token)
        changes.deletes.removeValue(forKey: member.id)
        changesByGroup[groupId] = changes

        publishPendingCount(for: groupId)
        scheduleFlush()
    }

    func queueDelete(memberId: UUID, groupId: String) {
        let token = UUID()
        dirtyJournal.recordDelete(memberId: memberId, groupId: groupId, token: token)

        var changes = changesByGroup[groupId] ?? PendingGroupChanges()
        changes.upserts.removeValue(forKey: memberId)
        changes.deletes[memberId] = PendingDelete(token: token)
        changesByGroup[groupId] = changes

        publishPendingCount(for: groupId)
        scheduleFlush()
    }

    func restorePendingChanges(users: [User], groupId: String?) {
        guard let groupId = CloudKitRouting.normalizedGroupId(groupId) else { return }

        let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        var changes = PendingGroupChanges()

        for entry in dirtyJournal.entries(groupId: groupId) {
            switch entry.operation {
            case .upsert:
                guard let member = entry.member ?? usersById[entry.memberId] else { continue }
                changes.upserts[entry.memberId] = PendingUpsert(member: member, token: entry.token)
                changes.deletes.removeValue(forKey: entry.memberId)

            case .delete:
                changes.upserts.removeValue(forKey: entry.memberId)
                changes.deletes[entry.memberId] = PendingDelete(token: entry.token)
            }
        }

        if changes.isEmpty {
            changesByGroup.removeValue(forKey: groupId)
        } else {
            changesByGroup[groupId] = changes
            scheduleFlush()
        }

        publishPendingCount(for: groupId)
    }

    func applyingPendingChanges(
        to cloudMembers: [CloudKitUserStore.CloudMember],
        groupId: String
    ) -> [CloudKitUserStore.CloudMember] {
        guard let changes = changesByGroup[groupId] else { return cloudMembers }

        var membersById = Dictionary(uniqueKeysWithValues: cloudMembers.map { ($0.id, $0) })

        for (memberId, pending) in changes.upserts {
            membersById[memberId] = CloudKitUserStore.CloudMember(
                id: pending.member.id,
                name: pending.member.name,
                avatarVersion: pending.member.avatarVersion,
                avatarData: avatarDataProvider(pending.member.id, groupId)
            )
        }

        for memberId in changes.deletes.keys {
            membersById.removeValue(forKey: memberId)
        }

        return membersById.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func flushImmediately() {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        Task { await flushNow() }
    }

    func pendingChangesCount(for groupId: String?) -> Int {
        guard let groupId = CloudKitRouting.normalizedGroupId(groupId) else { return 0 }
        return changesByGroup[groupId]?.count ?? 0
    }
}

private extension UserCloudSyncCoordinator {

    func scheduleFlush() {
        scheduledFlush?.cancel()
        scheduledFlush = Task { [debounceNanoseconds] in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            await flushNow()
        }
    }

    func flushNow() async {
        guard networkIsAvailable() else { return }

        let groupIds = changesByGroup.compactMap { groupId, changes in
            changes.isEmpty ? nil : groupId
        }

        for groupId in groupIds {
            await flush(groupId: groupId)
        }
    }

    func flush(groupId: String) async {
        guard flushingGroupIds.contains(groupId) == false else { return }
        guard let snapshot = changesByGroup[groupId], snapshot.isEmpty == false else { return }

        flushingGroupIds.insert(groupId)
        beginSync()
        defer {
            endSync()
            flushingGroupIds.remove(groupId)
        }

        do {
            for (_, pending) in snapshot.upserts {
                try await cloudStore.upsertMember(
                    id: pending.member.id,
                    name: pending.member.name,
                    avatarVersion: pending.member.avatarVersion,
                    avatarData: avatarDataProvider(pending.member.id, groupId),
                    clearsAvatar: pending.member.avatarVersion == nil,
                    groupId: groupId
                )

                finishUpsertIfCurrent(
                    memberId: pending.member.id,
                    token: pending.token,
                    groupId: groupId
                )
            }

            for (memberId, pending) in snapshot.deletes {
                try await cloudStore.deleteMember(id: memberId, groupId: groupId)
                finishDeleteIfCurrent(memberId: memberId, token: pending.token, groupId: groupId)
            }

            publishPendingCount(for: groupId)
            batchDidSucceed(groupId)

            if changesByGroup[groupId]?.isEmpty == false {
                scheduleFlush()
            }
        } catch {
            publishPendingCount(for: groupId)
            batchDidFail(error, groupId)
        }
    }

    func finishUpsertIfCurrent(memberId: UUID, token: UUID, groupId: String) {
        guard var changes = changesByGroup[groupId],
              changes.upserts[memberId]?.token == token else {
            return
        }

        changes.upserts.removeValue(forKey: memberId)
        dirtyJournal.remove(memberId: memberId, matchingToken: token, groupId: groupId)
        persist(changes, for: groupId)
    }

    func finishDeleteIfCurrent(memberId: UUID, token: UUID, groupId: String) {
        guard var changes = changesByGroup[groupId],
              changes.deletes[memberId]?.token == token else {
            return
        }

        changes.deletes.removeValue(forKey: memberId)
        dirtyJournal.remove(memberId: memberId, matchingToken: token, groupId: groupId)
        persist(changes, for: groupId)
    }

    private func persist(_ changes: PendingGroupChanges, for groupId: String) {
        if changes.isEmpty {
            changesByGroup.removeValue(forKey: groupId)
        } else {
            changesByGroup[groupId] = changes
        }
    }

    func publishPendingCount(for groupId: String) {
        pendingCountDidChange(changesByGroup[groupId]?.count ?? 0, groupId)
    }
}
