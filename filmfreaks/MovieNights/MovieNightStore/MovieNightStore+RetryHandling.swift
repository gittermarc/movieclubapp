//
//  MovieNightStore+RetryHandling.swift
//  filmfreaks
//
//  Split from MovieNightStore.swift (MOVIENIGHT-STORE-RESPONSIBILITY-SPLIT-1)
//

import Foundation
import Combine

extension MovieNightStore {

    // MARK: - Network reconnect handling

    func setupNetworkReconnectHandling() {
        // Seed with current state so we only react to transitions.
        lastNetworkConnected = NetworkMonitor.shared.isConnected

        networkCancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }

                Task { @MainActor in
                    let wasConnected = self.lastNetworkConnected
                    self.lastNetworkConnected = connected

                    guard Self.shouldFlushPendingChangesOnNetworkTransition(
                        from: wasConnected,
                        to: connected
                    ) else {
                        return
                    }

                    self.flushPendingCloudChanges()
                }
            }
    }

    // MARK: - GroupContext retry handling

    func setupGroupContextRetryHandling() {
        groupContextCancellable = NotificationCenter.default.publisher(for: .groupContextDidUpsert)
            .compactMap { $0.userInfo?["groupId"] as? String }
            .sink { [weak self] groupId in
                guard let self else { return }
                Task { @MainActor in
                    self.handleGroupContextUpsert(groupId: groupId)
                }
            }
    }

    func handleGroupContextUpsert(groupId: String) {
        guard let normalized = CloudKitRouting.normalizedGroupId(groupId) else { return }

        // Only relevant for UUID-like groupIds.
        guard CloudKitRouting.requiresGroupContext(for: normalized) else { return }
        guard GroupContextStore.context(forGroupId: normalized) != nil else { return }

        let now = Date()
        guard Self.shouldRetryGroupContext(
            lastAttemptAt: lastGroupContextRetryAtByGroup[normalized],
            now: now,
            minRetryInterval: minGroupContextRetryInterval
        ) else {
            return
        }

        lastGroupContextRetryAtByGroup[normalized] = now

        flushPendingCloudChanges()
        Task { await self.refreshFromCloud(groupId: normalized, force: true) }
    }

    nonisolated static func shouldFlushPendingChangesOnNetworkTransition(from wasConnected: Bool, to isConnected: Bool) -> Bool {
        isConnected && !wasConnected
    }

    nonisolated static func shouldRetryGroupContext(
        lastAttemptAt: Date?,
        now: Date,
        minRetryInterval: TimeInterval
    ) -> Bool {
        guard let lastAttemptAt else { return true }
        return now.timeIntervalSince(lastAttemptAt) >= minRetryInterval
    }
}
