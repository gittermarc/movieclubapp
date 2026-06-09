//
//  WatchProviderPreferencesStore.swift
//  filmfreaks
//

import Foundation

nonisolated struct WatchProviderPreferencesStore {
    private static let keyPrefix = "WatchProviderPreferences"
    private static let keySuffix = "v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func preferredProviderIDs(regionCode: String?) -> Set<Int> {
        let key = Self.storageKey(for: regionCode)
        let values = defaults.array(forKey: key) as? [Int] ?? []
        return Set(values.filter { $0 > 0 })
    }

    func setPreferredProviderIDs(_ providerIDs: Set<Int>, regionCode: String?) {
        let normalized = Array(providerIDs.filter { $0 > 0 }).sorted()
        defaults.set(normalized, forKey: Self.storageKey(for: regionCode))
    }

    @discardableResult
    func toggleProvider(_ providerID: Int, regionCode: String?) -> Set<Int> {
        guard providerID > 0 else { return preferredProviderIDs(regionCode: regionCode) }
        var ids = preferredProviderIDs(regionCode: regionCode)
        if ids.contains(providerID) {
            ids.remove(providerID)
        } else {
            ids.insert(providerID)
        }
        setPreferredProviderIDs(ids, regionCode: regionCode)
        return ids
    }

    func clear(regionCode: String?) {
        defaults.removeObject(forKey: Self.storageKey(for: regionCode))
    }

    static func storageKey(for regionCode: String?) -> String {
        let region = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
            ?? WatchProvidersRegionSettings.deviceRegionCode()
        return "\(keyPrefix).\(region).\(keySuffix)"
    }
}
