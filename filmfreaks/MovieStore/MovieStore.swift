//
//  MovieStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
internal import SwiftUI
import Combine

struct GroupInfo: Identifiable, Codable, Equatable {
    var id: String
    var name: String?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "Gruppe \(id.prefix(6))"
    }
}

@MainActor
class MovieStore: ObservableObject {

    @Published var movies: [Movie] = [] {
        didSet {
            handleMoviesDidSet(oldValue: oldValue)
        }
    }

    @Published var backlogMovies: [Movie] = [] {
        didSet {
            handleBacklogMoviesDidSet(oldValue: oldValue)
        }
    }

    @Published var isSyncing: Bool = false

    // MARK: - Sync transparency (per group)

    /// Number of locally queued changes that still need to be pushed to iCloud.
    @Published var pendingCloudChangesCount: Int = 0

    /// Timestamp of the last successful sync (fetch or upload) for the current group.
    @Published var lastCloudSyncAt: Date?

    /// Last sync error message (best effort). Cleared on success.
    @Published var lastCloudSyncError: String?

    @Published var currentGroupId: String? {
        didSet {
            handleCurrentGroupIdDidSet()
        }
    }

    @Published var currentGroupName: String? {
        didSet {
            handleCurrentGroupNameDidSet()
        }
    }

    @Published var knownGroups: [GroupInfo] = [] {
        didSet { saveKnownGroups() }
    }

    // NOTE: Marked as internal so the implementation can live in file-split extensions.
    // Treat as implementation detail of MovieStore.
    let cloudStore: CloudKitMovieStore?
    let cloudRatingStore: CloudKitRatingStore?

    // ✅ must be var: we initialize it only after `self` is fully initialized
    var cloudSyncCoordinator: MovieCloudSyncCoordinator?

    var isApplyingCloudUpdate = false

    /// When we mutate embedded `Movie.ratings`, we must NOT enqueue movie CloudKit diffs.
    /// Ratings are synced as separate CloudKit records (MovieRating).
    var isApplyingRatingUpdate = false

    // Combined sync state (fetch + upload). We use a counter to avoid flicker.
    var syncCount: Int = 0
    var isRefreshingFromCloud: Bool = false

    // Throttle gegen zu viele Cloud-Fetches
    var lastRefreshAt: Date?
    let minRefreshInterval: TimeInterval = 8

    // MARK: - Network reconnect handling

    /// Combine subscription that detects offline → online transitions.
    /// We use this to flush debounced/batched CloudKit writes as soon as the device
    /// reconnects, even if the user isn't currently on the main ContentView.
    var networkCancellable: AnyCancellable?
    var lastNetworkConnected: Bool = true

    // MARK: - GroupContext retry handling

    /// When a UUID-like groupId becomes routable (GroupContext persisted), automatically:
    /// - flush pending writes
    /// - refresh from cloud (zone changes)
    var groupContextCancellable: AnyCancellable?
    var lastGroupContextRetryAtByGroup: [String: Date] = [:]
    let minGroupContextRetryInterval: TimeInterval = 2

    // ✅ Migration Guard
    var isMigratingCast = false

    init(useCloud: Bool = true) {

        // 1) Initialize all stored properties WITHOUT capturing `self`
        if useCloud {
            self.cloudStore = CloudKitMovieStore()
            self.cloudRatingStore = CloudKitRatingStore()
        } else {
            self.cloudStore = nil
            self.cloudRatingStore = nil
        }
        self.cloudSyncCoordinator = nil

        // 2) Load persisted state
        self.knownGroups = Self.loadKnownGroups()

        self.currentGroupId = UserDefaults.standard.string(forKey: "CurrentGroupId")
        self.currentGroupName = UserDefaults.standard.string(forKey: "CurrentGroupName")

        // Load per-group sync meta (pending, last sync, last error)
        loadSyncMetaForCurrentGroup()

        addOrUpdateCurrentGroupInKnownGroups()

        // 3) Load local caches without triggering persistence/sync noise
        isApplyingCloudUpdate = true
        let stored = PersistenceManager.shared.loadMovies(groupId: currentGroupId)
        self.movies = stored

        let backlogStored = PersistenceManager.shared.loadBacklogMovies(groupId: currentGroupId)
        self.backlogMovies = backlogStored
        isApplyingCloudUpdate = false

        // ✅ Automatische Migration (lokale Daten)
        Task { await self.migrateCastDataIfNeeded() }

        // 4) Now `self` is fully initialized -> safe to capture `self` in closures.
        configureCloudSyncIfNeeded(useCloud: useCloud)

        // Always listen for reconnects; flush is a no-op if Cloud sync isn't enabled.
        setupNetworkReconnectHandling()

        // When routing becomes available for a Sharing/Zone group, retry flush + refresh.
        setupGroupContextRetryHandling()
    }

    // MARK: - Preview

    static func preview() -> MovieStore {
        let store = MovieStore(useCloud: false)
        if store.movies.isEmpty {
            store.movies = sampleMovies
        }
        return store
    }
}
