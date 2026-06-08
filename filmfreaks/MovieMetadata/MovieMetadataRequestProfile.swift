//
//  MovieMetadataRequestProfile.swift
//  filmfreaks
//

import Foundation

enum MovieMetadataRequestProfile: Hashable, Sendable {
    case detailPage(regionCode: String)
    case quickAdd

    var normalizedRegionCode: String? {
        switch self {
        case .detailPage(let regionCode):
            return WatchProvidersRegionSettings.normalizedRegionCode(regionCode)
        case .quickAdd:
            return nil
        }
    }

    var normalizedForCache: MovieMetadataRequestProfile {
        switch self {
        case .detailPage(let regionCode):
            let fallback = regionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return .detailPage(regionCode: normalizedRegionCode ?? fallback)
        case .quickAdd:
            return .quickAdd
        }
    }
}

struct MovieMetadataRequestKey: Hashable, Sendable {
    let movieID: Int
    let profile: MovieMetadataRequestProfile
}

struct MovieMetadataWatchProvidersKey: Hashable, Sendable {
    let movieID: Int
    let regionCode: String?
}
