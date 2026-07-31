//
//  UserStore+CloudQueue.swift
//  filmfreaks
//
//  Member CloudKit outbox, reconnect retry and avatar-cache reconciliation.
//

import Combine
import Foundation

extension UserStore {

    // MARK: - Outbox setup

    func configureMemberCloudSync() {
        memberCloudSyncCoordinator = UserCloudSyncCoordinator(
            cloudStore: cloudStore,
            avatarDataProvider: { [weak self] memberId, groupId in
                self?.avatarStorage.avatarData(memberId: memberId, groupId: groupId)
            },
            beginSync: { [weak self] in
                self?.beginCloudSync()
            },
            endSync: { [weak self] in
                self?.endCloudSync()
            },
            networkIsAvailable: {
                NetworkMonitor.shared.isConnected
            },
            pendingCountDidChange: { [weak self] count, groupId in
                self?.applyPendingCloudChangesCount(count, forGroupId: groupId)
            },
            batchDidSucceed: { [weak self] groupId in
                self?.recordCloudSyncSuccess(forGroupId: groupId)
            },
            batchDidFail: { [weak self] error, groupId in
                self?.recordCloudSyncError(error, forGroupId: groupId)
            }
        )
    }

    func restorePendingMemberCloudWrites(forGroupId groupId: String?) {
        memberCloudSyncCoordinator.restorePendingChanges(users: users, groupId: groupId)
        updatePendingCloudChangesCount(
            memberCloudSyncCoordinator.pendingChangesCount(for: groupId)
        )
    }

    func flushPendingMemberCloudChanges() {
        memberCloudSyncCoordinator.flushImmediately()
    }

    // MARK: - Local-first mutations

    func queueMemberUpsertForCloud(_ member: User) {
        guard let groupId = CloudKitRouting.normalizedGroupId(currentGroupId) else { return }
        memberCloudSyncCoordinator.queueUpsert(member: member, groupId: groupId)
    }

    func queueMemberDeleteForCloud(memberId: UUID) {
        guard let groupId = CloudKitRouting.normalizedGroupId(currentGroupId) else { return }
        memberCloudSyncCoordinator.queueDelete(memberId: memberId, groupId: groupId)
    }

    func membersApplyingPendingCloudChanges(
        _ cloudMembers: [CloudKitUserStore.CloudMember],
        groupId: String
    ) -> [CloudKitUserStore.CloudMember] {
        memberCloudSyncCoordinator.applyingPendingChanges(to: cloudMembers, groupId: groupId)
    }

    // MARK: - Retry and routing readiness

    func setupMemberCloudRetryHandling() {
        lastNetworkConnected = NetworkMonitor.shared.isConnected

        networkCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] isConnected in
                guard let self else { return }
                Task { @MainActor in
                    let wasConnected = self.lastNetworkConnected
                    self.lastNetworkConnected = isConnected

                    guard isConnected, wasConnected == false else { return }
                    self.flushPendingMemberCloudChanges()
                }
            }

        groupContextCancellable = NotificationCenter.default.publisher(for: .groupContextDidUpsert)
            .compactMap { $0.userInfo?["groupId"] as? String }
            .sink { [weak self] groupId in
                guard let self else { return }
                Task { @MainActor in
                    guard let normalizedGroupId = CloudKitRouting.normalizedGroupId(groupId),
                          CloudKitRouting.requiresGroupContext(for: normalizedGroupId),
                          GroupContextStore.context(forGroupId: normalizedGroupId) != nil else {
                        return
                    }

                    self.flushPendingMemberCloudChanges()

                    if CloudKitRouting.normalizedGroupId(self.currentGroupId) == normalizedGroupId {
                        await self.refreshFromCloud(force: true)
                    }
                }
            }
    }

    // MARK: - Sync status and avatar cache

    func beginCloudSync() {
        activeCloudSyncOperationCount += 1
        isSyncing = true
        lastCloudSyncAttemptAt = Date()
    }

    func endCloudSync() {
        activeCloudSyncOperationCount = max(0, activeCloudSyncOperationCount - 1)
        isSyncing = activeCloudSyncOperationCount > 0
    }

    func applyPendingCloudChangesCount(_ count: Int, forGroupId groupId: String) {
        guard syncKey(for: groupId) == syncKey(for: currentGroupId) else { return }
        updatePendingCloudChangesCount(count)
    }

    func reconcileAvatarCache(
        for member: CloudKitUserStore.CloudMember,
        previousAvatarVersion: String?,
        groupId: String
    ) {
        if let avatarVersion = member.avatarVersion,
           avatarVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            if let avatarData = member.avatarData {
                try? avatarStorage.storeAvatar(
                    avatarData,
                    memberId: member.id,
                    groupId: groupId
                )
            } else if previousAvatarVersion != avatarVersion {
                try? avatarStorage.removeAvatar(memberId: member.id, groupId: groupId)
            }
        } else {
            try? avatarStorage.removeAvatar(memberId: member.id, groupId: groupId)
        }
    }
}
