//
//  MovieDiscoveryShelf.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieDiscoveryShelf: Identifiable, Codable, Equatable, Sendable {
    let kind: MovieDiscoveryShelfKind
    let title: String
    let subtitle: String?
    let results: [TMDbMovieResult]
    let seedTitle: String?
    let lastUpdated: Date?
    let freshness: TMDbMetadataCacheFreshness?
    let errorMessage: String?

    var id: String { kind.rawValue }

    init(
        kind: MovieDiscoveryShelfKind,
        title: String? = nil,
        subtitle: String? = nil,
        results: [TMDbMovieResult],
        seedTitle: String? = nil,
        lastUpdated: Date? = nil,
        freshness: TMDbMetadataCacheFreshness? = nil,
        errorMessage: String? = nil
    ) {
        self.kind = kind
        self.title = title ?? kind.title
        self.subtitle = subtitle
        self.results = results
        self.seedTitle = seedTitle
        self.lastUpdated = lastUpdated
        self.freshness = freshness
        self.errorMessage = errorMessage
    }

    var hasVisibleContent: Bool {
        !results.isEmpty
    }
}

nonisolated struct MovieDiscoveryResponse: Codable, Equatable, Sendable {
    let kind: MovieDiscoveryShelfKind
    let results: [TMDbMovieResult]
    let seedTitle: String?
    let generatedAt: Date

    func shelf(regionCode: String?, freshness: TMDbMetadataCacheFreshness?) -> MovieDiscoveryShelf {
        MovieDiscoveryShelf(
            kind: kind,
            subtitle: kind.subtitle(regionCode: regionCode, seedTitle: seedTitle),
            results: results,
            seedTitle: seedTitle,
            lastUpdated: generatedAt,
            freshness: freshness
        )
    }
}

nonisolated struct MovieDiscoveryLoadResult: Equatable, Sendable {
    let shelves: [MovieDiscoveryShelf]
    let usedStaleCache: Bool
}
