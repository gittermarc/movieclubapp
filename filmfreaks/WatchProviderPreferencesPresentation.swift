//
//  WatchProviderPreferencesPresentation.swift
//  filmfreaks
//

import Foundation

nonisolated enum WatchProviderPreferencesPresentation {
    static func sortedCatalog(_ providers: [TMDbWatchProvider]) -> [TMDbWatchProvider] {
        deduplicated(providers).sorted { left, right in
            let leftPriority = left.display_priority ?? Int.max
            let rightPriority = right.display_priority ?? Int.max
            if leftPriority != rightPriority { return leftPriority < rightPriority }
            return left.provider_name.localizedCaseInsensitiveCompare(right.provider_name) == .orderedAscending
        }
    }

    static func filteredCatalog(_ providers: [TMDbWatchProvider], query: String) -> [TMDbWatchProvider] {
        let sorted = sortedCatalog(providers)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter { provider in
            provider.provider_name.localizedCaseInsensitiveContains(trimmed)
            || String(provider.provider_id).contains(trimmed)
        }
    }

    static func selectedProviderNames(
        from providers: [TMDbWatchProvider],
        selectedIDs: Set<Int>,
        limit: Int = 3
    ) -> [String] {
        sortedCatalog(providers)
            .filter { selectedIDs.contains($0.provider_id) }
            .prefix(max(0, limit))
            .map(\.provider_name)
    }

    static func summaryText(
        selectedIDs: Set<Int>,
        providers: [TMDbWatchProvider]
    ) -> String {
        guard !selectedIDs.isEmpty else { return "Keine Anbieter ausgewählt" }
        let names = selectedProviderNames(from: providers, selectedIDs: selectedIDs, limit: 3)
        if names.isEmpty {
            return selectedIDs.count == 1 ? "1 Anbieter ausgewählt" : "\(selectedIDs.count) Anbieter ausgewählt"
        }
        let suffix = selectedIDs.count > names.count ? " +\(selectedIDs.count - names.count)" : ""
        return names.joined(separator: ", ") + suffix
    }

    private static func deduplicated(_ providers: [TMDbWatchProvider]) -> [TMDbWatchProvider] {
        var seen = Set<Int>()
        var output: [TMDbWatchProvider] = []
        for provider in providers where !seen.contains(provider.provider_id) {
            seen.insert(provider.provider_id)
            output.append(provider)
        }
        return output
    }
}
