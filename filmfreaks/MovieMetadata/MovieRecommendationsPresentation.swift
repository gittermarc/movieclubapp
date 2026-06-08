//
//  MovieRecommendationsPresentation.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieRecommendationsPresentation: Equatable, Sendable {
    let title: String
    let subtitle: String?
    let items: [MovieRecommendationPresentationItem]

    static func make(
        recommendations: [TMDbMovieResult],
        source: MovieMetadataRecommendationSource?,
        currentTMDbId: Int?,
        watchedMovies: [Movie],
        backlogMovies: [Movie],
        limit: Int = 12
    ) -> MovieRecommendationsPresentation? {
        var seenIDs: Set<Int> = []
        var items: [MovieRecommendationPresentationItem] = []
        items.reserveCapacity(min(limit, recommendations.count))

        for result in recommendations {
            if let currentTMDbId, result.id == currentTMDbId { continue }
            guard seenIDs.insert(result.id).inserted else { continue }

            let year = MovieMetadataMembershipResolver.year(from: result.release_date)
            let membershipState = MovieMetadataMembershipResolver.state(
                tmdbId: result.id,
                title: result.title,
                year: year,
                currentTMDbId: currentTMDbId,
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies
            )

            guard membershipState == .missing else { continue }

            items.append(
                MovieRecommendationPresentationItem(
                    result: result,
                    membershipState: membershipState
                )
            )

            if items.count >= limit { break }
        }

        guard !items.isEmpty else { return nil }

        return MovieRecommendationsPresentation(
            title: "Mehr wie dieser Film",
            subtitle: source == .similar ? "Ähnliche Filme" : nil,
            items: items
        )
    }
}

nonisolated struct MovieRecommendationPresentationItem: Identifiable, Equatable, Sendable {
    let result: TMDbMovieResult
    let membershipState: MovieMetadataMembershipState

    var id: Int { result.id }

    var title: String { result.title }

    var yearText: String? {
        MovieMetadataMembershipResolver.year(from: result.release_date)
    }

    var ratingText: String? {
        guard result.vote_average > 0 else { return nil }
        return String(format: "%.1f", result.vote_average)
    }

    var posterURL: URL? {
        MovieMetadataPresentation.posterURL(path: result.poster_path, width: .w342)
    }

    var backdropURL: URL? {
        MovieMetadataPresentation.backdropURL(path: result.backdrop_path, width: .w780)
    }
}
