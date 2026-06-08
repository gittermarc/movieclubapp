//
//  MovieCollectionPresentation.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieCollectionPresentation: Equatable, Sendable {
    let title: String
    let subtitle: String?
    let items: [MovieCollectionPartPresentation]

    static func make(
        collectionDetails: TMDbCollectionDetails?,
        currentTMDbId: Int?,
        watchedMovies: [Movie],
        backlogMovies: [Movie]
    ) -> MovieCollectionPresentation? {
        guard let collectionDetails else { return nil }

        let sortedParts = collectionDetails.parts.sorted(by: sortParts)
        guard sortedParts.count > 1 else { return nil }

        let items = sortedParts.map { part in
            MovieCollectionPartPresentation(
                part: part,
                membershipState: MovieMetadataMembershipResolver.state(
                    tmdbId: part.id,
                    title: part.title,
                    year: MovieMetadataMembershipResolver.year(from: part.release_date),
                    currentTMDbId: currentTMDbId,
                    watchedMovies: watchedMovies,
                    backlogMovies: backlogMovies
                )
            )
        }

        let missingCount = items.filter { $0.membershipState == .missing }.count
        let subtitle: String?
        if missingCount == 0 {
            subtitle = "Reihe komplett in deinen Listen"
        } else if missingCount == 1 {
            subtitle = "1 Teil fehlt noch"
        } else {
            subtitle = "\(missingCount) Teile fehlen noch"
        }

        return MovieCollectionPresentation(
            title: collectionDetails.name,
            subtitle: subtitle,
            items: items
        )
    }

    private static func sortParts(_ left: TMDbCollectionPart, _ right: TMDbCollectionPart) -> Bool {
        let leftDate = sortableReleaseDate(left.release_date)
        let rightDate = sortableReleaseDate(right.release_date)

        switch (leftDate, rightDate) {
        case let (leftDate?, rightDate?):
            if leftDate != rightDate { return leftDate < rightDate }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }

        return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
    }

    private static func sortableReleaseDate(_ releaseDate: String?) -> String? {
        guard let releaseDate else { return nil }
        let trimmed = releaseDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        return String(trimmed.prefix(10))
    }
}

nonisolated struct MovieCollectionPartPresentation: Identifiable, Equatable, Sendable {
    let part: TMDbCollectionPart
    let membershipState: MovieMetadataMembershipState

    var id: Int { part.id }

    var title: String { part.title }

    var yearText: String? {
        MovieMetadataMembershipResolver.year(from: part.release_date)
    }

    var ratingText: String? {
        guard part.vote_average > 0 else { return nil }
        return String(format: "%.1f", part.vote_average)
    }

    var posterURL: URL? {
        MovieMetadataPresentation.posterURL(path: part.poster_path, width: .w342)
    }

    var backdropURL: URL? {
        MovieMetadataPresentation.backdropURL(path: part.backdrop_path, width: .w780)
    }

    var result: TMDbMovieResult {
        MovieMetadataMembershipResolver.result(from: part)
    }
}
