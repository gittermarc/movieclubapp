//
//  WatchProviderPreferences.swift
//  filmfreaks
//

import Foundation

nonisolated struct WatchProviderPreferences: Codable, Equatable, Sendable {
    let regionCode: String
    let providerIDs: Set<Int>

    init(regionCode: String, providerIDs: Set<Int>) {
        self.regionCode = WatchProvidersRegionSettings.normalizedRegionCode(regionCode) ?? regionCode.uppercased()
        self.providerIDs = providerIDs.filter { $0 > 0 }
    }
}
