//
//  TMDbMetadataCacheKey.swift
//  filmfreaks
//

import Foundation

nonisolated struct TMDbMetadataCacheKey: Codable, Hashable, Sendable {
    let namespace: String
    let movieID: Int?
    let collectionID: Int?
    let regionCode: String?
    let profileName: String?
    let variant: String?

    init(
        namespace: String,
        movieID: Int? = nil,
        collectionID: Int? = nil,
        regionCode: String? = nil,
        profileName: String? = nil,
        variant: String? = nil
    ) {
        self.namespace = namespace
        self.movieID = movieID
        self.collectionID = collectionID
        self.regionCode = regionCode.flatMap { WatchProvidersRegionSettings.normalizedRegionCode($0) }
        self.profileName = profileName
        self.variant = variant
    }

    static func metadata(movieID: Int, profile: MovieMetadataRequestProfile) -> TMDbMetadataCacheKey {
        let normalizedProfile = profile.normalizedForCache
        switch normalizedProfile {
        case .detailPage(let regionCode):
            return TMDbMetadataCacheKey(
                namespace: "metadata",
                movieID: movieID,
                regionCode: regionCode,
                profileName: "detailPage"
            )
        case .quickAdd:
            return TMDbMetadataCacheKey(
                namespace: "metadata",
                movieID: movieID,
                profileName: "quickAdd"
            )
        }
    }

    static func movieDetails(movieID: Int) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey(namespace: "movieDetails", movieID: movieID)
    }

    static func watchProviders(movieID: Int, regionCode: String?) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey(namespace: "watchProviders", movieID: movieID, regionCode: regionCode)
    }


    static func watchProviderCatalog(regionCode: String?) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey(namespace: "watchProviderCatalog", regionCode: regionCode)
    }

    static func collectionDetails(collectionID: Int) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey(namespace: "collectionDetails", collectionID: collectionID)
    }

    static func recommendations(movieID: Int) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey(namespace: "recommendations", movieID: movieID)
    }

    static func discoveryShelf(
        kind: String,
        regionCode: String? = nil,
        variant: String? = nil
    ) -> TMDbMetadataCacheKey {
        TMDbMetadataCacheKey(
            namespace: "discovery",
            regionCode: regionCode,
            profileName: kind,
            variant: variant
        )
    }

    var rawValue: String {
        [
            "v1",
            namespace,
            movieID.map { "movie-\($0)" },
            collectionID.map { "collection-\($0)" },
            regionCode.map { "region-\($0)" },
            profileName.map { "profile-\($0)" },
            variant.map { "variant-\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "|")
    }

    var fileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitizedScalars = rawValue.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(sanitizedScalars) + ".json"
    }
}
