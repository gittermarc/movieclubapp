//
//  MovieNightStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

import Foundation
internal import SwiftUI
import Combine

/// Group-scoped store for movie night proposals and responses.
///
/// P0: Local-only persistence (JSON) via `MovieNightLocalPersistence`.
/// P2: Adds local activity events + accept/decline flow.
@MainActor
final class MovieNightStore: ObservableObject {

    // MARK: - Published state

    @Published var eventsByGroup: [String: [MovieNightEvent]] = [:]
    @Published var responsesByGroup: [String: [MovieNightResponse]] = [:]
    @Published var activityByGroup: [String: [MovieNightActivityEvent]] = [:]
    @Published var isLoaded: Bool = false

    // MARK: - Sync transparency (per group)

    /// Combined sync state (fetch + upload). We use a counter to avoid flicker.
    @Published var isSyncing: Bool = false

    /// Number of locally queued changes that still need to be pushed to iCloud (per group).
    @Published var pendingCloudChangesByGroup: [String: Int] = [:]

    /// Timestamp of the last successful sync (fetch or upload) per group.
    @Published var lastCloudSyncAtByGroup: [String: Date] = [:]

    /// Last sync error message (best effort) per group. Cleared on success.
    @Published var lastCloudSyncErrorByGroup: [String: String] = [:]

    // MARK: - Cloud

    let useCloud: Bool
    let cloudStore: CloudKitMovieNightStore?

    var isRefreshingFromCloud: Bool = false
    var lastRefreshAtByGroup: [String: Date] = [:]
    let minRefreshInterval: TimeInterval = 8

    var cloudSyncCoordinator: MovieNightCloudSyncCoordinator?

    // Combined sync state (fetch + upload). We use a counter to avoid flicker.
    var syncCount: Int = 0

    // MARK: - Network reconnect handling

    var networkCancellable: AnyCancellable?
    var lastNetworkConnected: Bool = true

    // MARK: - GroupContext retry handling

    /// When a Sharing/Zone group becomes routable (GroupContext persisted), automatically:
    /// - flush pending writes
    /// - refresh from cloud
    var groupContextCancellable: AnyCancellable?
    var lastGroupContextRetryAtByGroup: [String: Date] = [:]
    let minGroupContextRetryInterval: TimeInterval = 2

    // UserDefaults base key (per group)
    static let syncMetaPrefix = "MovieNightStore.SyncMeta."

    var initialLoadTask: Task<Void, Never>?

    let persistence = MovieNightLocalPersistence()

    init(useCloud: Bool = true, cloudStore: CloudKitMovieNightStore? = nil) {
        self.useCloud = useCloud

        if useCloud {
            // Avoid constructing a MainActor-isolated CloudKit store as a default argument.
            // Default arguments are evaluated in the caller's context, which can be nonisolated.
            let resolved = cloudStore ?? CloudKitMovieNightStore()
            self.cloudStore = resolved
        } else {
            self.cloudStore = nil
        }

        self.initialLoadTask = Task { @MainActor in
            let snapshot = await persistence.load()
            self.eventsByGroup = snapshot.eventsByGroup
            self.responsesByGroup = snapshot.responsesByGroup
            self.activityByGroup = snapshot.activityByGroup
            self.isLoaded = true
        }

        if useCloud, let cloudStore = self.cloudStore {
            self.cloudSyncCoordinator = MovieNightCloudSyncCoordinator(
                cloudStore: cloudStore,
                beginSync: { [weak self] in self?.beginSync() },
                endSync: { [weak self] in self?.endSync() },
                networkIsAvailable: { NetworkMonitor.shared.isConnected },
                pendingCountDidChange: { [weak self] count, groupId in
                    self?.applyPendingCount(count, forGroupId: groupId)
                },
                batchDidSucceed: { [weak self] groupId in
                    self?.markCloudSyncSuccess(forGroupId: groupId)
                },
                batchDidFail: { [weak self] error, groupId in
                    self?.markCloudSyncFailure(error, forGroupId: groupId)
                }
            )
        }

        setupNetworkReconnectHandling()
        setupGroupContextRetryHandling()
    }
}
