//
//  MovieMetadataRecommendationSource.swift
//  filmfreaks
//

import Foundation

nonisolated enum MovieMetadataRecommendationSource: String, Codable, Equatable, Sendable {
    case recommendations
    case similar
}
