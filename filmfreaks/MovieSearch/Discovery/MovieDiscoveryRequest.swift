//
//  MovieDiscoveryRequest.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieDiscoveryRequest: Equatable, Sendable {
    let existingWatched: [Movie]
    let existingBacklog: [Movie]
    let localWatchedKeys: Set<String>
    let localBacklogKeys: Set<String>
    let regionCode: String?
    let limitPerShelf: Int

    init(
        existingWatched: [Movie],
        existingBacklog: [Movie],
        localWatchedKeys: Set<String>,
        localBacklogKeys: Set<String>,
        regionCode: String?,
        limitPerShelf: Int = 12
    ) {
        self.existingWatched = existingWatched
        self.existingBacklog = existingBacklog
        self.localWatchedKeys = localWatchedKeys
        self.localBacklogKeys = localBacklogKeys
        self.regionCode = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
        self.limitPerShelf = max(1, limitPerShelf)
    }
}
