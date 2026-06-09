//
//  WatchProvidersAvailabilityPresentation.swift
//  filmfreaks
//

import Foundation

nonisolated extension TMDbWatchProvidersCountry {
    /// Best-effort Liste von Anbietern, in sinnvoller Priorität:
    /// flatrate (Abo) -> free -> ads -> rent -> buy.
    var bestEffortProviders: [TMDbWatchProvider] {
        let groups: [[TMDbWatchProvider]] = [
            flatrate ?? [],
            free ?? [],
            ads ?? [],
            rent ?? [],
            buy ?? []
        ]

        var seen = Set<Int>()
        var output: [TMDbWatchProvider] = []

        for group in groups {
            let sorted = group.sorted {
                ($0.display_priority ?? Int.max) < ($1.display_priority ?? Int.max)
            }

            for provider in sorted where !seen.contains(provider.provider_id) {
                seen.insert(provider.provider_id)
                output.append(provider)
            }
        }

        return output
    }
}

nonisolated enum WatchProvidersAvailabilityPresentation {
    static func sortedDeduplicated(
        _ providers: [TMDbWatchProvider],
        preferredProviderIDs: Set<Int>
    ) -> [TMDbWatchProvider] {
        var seen = Set<Int>()
        let deduped = providers.filter { provider in
            guard !seen.contains(provider.provider_id) else { return false }
            seen.insert(provider.provider_id)
            return true
        }

        return deduped.sorted { left, right in
            let leftPreferred = preferredProviderIDs.contains(left.provider_id)
            let rightPreferred = preferredProviderIDs.contains(right.provider_id)
            if leftPreferred != rightPreferred { return leftPreferred }

            let leftPriority = left.display_priority ?? Int.max
            let rightPriority = right.display_priority ?? Int.max
            if leftPriority != rightPriority { return leftPriority < rightPriority }

            return left.provider_name.localizedCaseInsensitiveCompare(right.provider_name) == .orderedAscending
        }
    }

    static func availablePreferredProviders(
        in country: TMDbWatchProvidersCountry,
        preferredProviderIDs: Set<Int>
    ) -> [TMDbWatchProvider] {
        guard !preferredProviderIDs.isEmpty else { return [] }
        return sortedDeduplicated(country.bestEffortProviders, preferredProviderIDs: preferredProviderIDs)
            .filter { preferredProviderIDs.contains($0.provider_id) }
    }

    static func preferredSummaryText(
        in country: TMDbWatchProvidersCountry,
        preferredProviderIDs: Set<Int>
    ) -> String? {
        let providers = availablePreferredProviders(in: country, preferredProviderIDs: preferredProviderIDs)
        guard !providers.isEmpty else { return nil }
        let names = providers.prefix(3).map(\.provider_name).joined(separator: ", ")
        let suffix = providers.count > 3 ? " +\(providers.count - 3)" : ""
        return "Deine Anbieter verfügbar: \(names)\(suffix)"
    }
}
