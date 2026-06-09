//
//  MovieQuickAddEnrichmentService.swift
//  filmfreaks
//

import Foundation

nonisolated struct MovieQuickAddEnrichmentService: Sendable {
    let repository: TMDbMetadataRepository

    init(repository: TMDbMetadataRepository = TMDbMetadataRepository(cacheStore: TMDbMetadataCacheFileStore())) {
        self.repository = repository
    }

    func loadPatch(for request: MovieQuickAddEnrichmentRequest) async -> MovieMetadataLoadedMoviePatch? {
        guard Self.needsEnrichment(movie: request.movieSnapshot) else {
            return nil
        }

        do {
            let response = try await repository.metadata(for: request.tmdbId, profile: .quickAdd)
            let patch = MovieMetadataLoadedMoviePatch(details: response.details)
            let updatedMovie = patch.applied(to: request.movieSnapshot)
            guard updatedMovie != request.movieSnapshot else {
                return nil
            }
            return patch
        } catch {
            return nil
        }
    }

    static func needsEnrichment(movie: Movie) -> Bool {
        guard movie.tmdbId != nil else { return false }

        if movie.genres?.isEmpty != false { return true }
        if movie.genreIds?.isEmpty != false { return true }
        if movie.keywords?.isEmpty != false { return true }
        if movie.keywordIds?.isEmpty != false { return true }
        if movie.cast?.isEmpty != false { return true }
        if movie.directors?.isEmpty != false { return true }
        if isBlank(movie.posterPath) { return true }
        if movie.tmdbRating == nil { return true }

        return false
    }

    private static func isBlank(_ value: String?) -> Bool {
        guard let value else { return true }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
