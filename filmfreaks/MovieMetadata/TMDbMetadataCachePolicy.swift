//
//  TMDbMetadataCachePolicy.swift
//  filmfreaks
//

import Foundation

nonisolated enum TMDbMetadataCachePolicy: Equatable, Sendable {
    case movieDetails
    case collectionDetails
    case recommendations
    case watchProviders
    case negativeRecommendations
    case negativeWatchProviders

    var freshDuration: TimeInterval {
        switch self {
        case .movieDetails, .collectionDetails:
            return 30 * 24 * 60 * 60
        case .recommendations:
            return 24 * 60 * 60
        case .watchProviders:
            return 6 * 60 * 60
        case .negativeRecommendations:
            return 6 * 60 * 60
        case .negativeWatchProviders:
            return 2 * 60 * 60
        }
    }

    var staleDuration: TimeInterval {
        switch self {
        case .movieDetails, .collectionDetails:
            return 90 * 24 * 60 * 60
        case .recommendations:
            return 7 * 24 * 60 * 60
        case .watchProviders:
            return 24 * 60 * 60
        case .negativeRecommendations:
            return 24 * 60 * 60
        case .negativeWatchProviders:
            return 12 * 60 * 60
        }
    }

    func dates(now: Date) -> (expiresAt: Date, staleUntil: Date) {
        let expiresAt = now.addingTimeInterval(freshDuration)
        let staleUntil = now.addingTimeInterval(staleDuration)
        return (expiresAt, staleUntil)
    }
}
