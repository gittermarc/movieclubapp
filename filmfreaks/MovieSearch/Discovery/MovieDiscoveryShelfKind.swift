//
//  MovieDiscoveryShelfKind.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieDiscoveryShelfKind: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case personalizedRecommendations
    case trending
    case topRated
    case nowPlaying
    case popular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personalizedRecommendations:
            return "Für euch empfohlen"
        case .trending:
            return "Gerade angesagt"
        case .topRated:
            return "Top bewertet"
        case .nowPlaying:
            return "Neu im Kino"
        case .popular:
            return "Beliebt auf TMDb"
        }
    }

    func subtitle(regionCode: String?, seedTitle: String?) -> String? {
        switch self {
        case .personalizedRecommendations:
            if let seedTitle, !seedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Basierend auf „\(seedTitle)“ und ähnlichen Filmen"
            }
            return "Aus eurer Filmhistorie abgeleitet"
        case .trending:
            return "Was TMDb diese Woche bewegt"
        case .topRated:
            return "Stark bewertete Filme für eure Watchlist"
        case .nowPlaying:
            let region = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
            guard let region else { return "Aktuelle Kinostarts" }
            let name = WatchProvidersRegionSettings.germanDisplayName(for: region)
            let flag = WatchProvidersRegionSettings.flagEmoji(for: region)
            return "Kinostarts in \(flag) \(name)"
        case .popular:
            return "Bewährter Fallback, wenn ihr einfach stöbern wollt"
        }
    }

    var symbolName: String {
        switch self {
        case .personalizedRecommendations:
            return "sparkles"
        case .trending:
            return "flame.fill"
        case .topRated:
            return "star.fill"
        case .nowPlaying:
            return "ticket.fill"
        case .popular:
            return "chart.line.uptrend.xyaxis"
        }
    }
}
