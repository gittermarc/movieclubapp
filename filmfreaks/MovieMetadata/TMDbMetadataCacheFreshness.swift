//
//  TMDbMetadataCacheFreshness.swift
//  filmfreaks
//

import Foundation

nonisolated enum TMDbMetadataCacheFreshness: String, Codable, Equatable, Sendable {
    case fresh
    case stale
    case expired

    var isUsable: Bool {
        self == .fresh || self == .stale
    }

    var shouldRevalidate: Bool {
        self == .stale || self == .expired
    }
}
