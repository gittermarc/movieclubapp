//
//  GoalsView+TMDb.swift
//  filmfreaks
//
//  TMDb helpers used by GoalsView (genres + lightweight caching).
//

internal import SwiftUI

extension GoalsView {

    // MARK: - TMDb Genres

    func computedGenresForEditor() -> [TMDbGenre] {
        if !tmdbGenres.isEmpty { return tmdbGenres }

        // Fallback: aus vorhandenen Filmen ableiten (ohne IDs)
        let names = Set(movieStore.movies.flatMap { $0.genres ?? [] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })

        return names.sorted().enumerated().map { idx, name in
            TMDbGenre(id: -(idx + 1), name: name) // negative IDs = local-only
        }
    }

    func loadGenresIfNeeded() async {
        if !tmdbGenres.isEmpty || isLoadingGenres { return }
        isLoadingGenres = true
        defer { isLoadingGenres = false }

        // Cache aus UserDefaults
        let cacheKey = "TMDb.GenreList.de-DE.v1"
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([TMDbGenre].self, from: data),
           !decoded.isEmpty {
            tmdbGenres = decoded
            return
        }

        do {
            let fetched = try await TMDbAPI.shared.fetchMovieGenreList()
            await MainActor.run {
                tmdbGenres = fetched.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
                if let data = try? JSONEncoder().encode(tmdbGenres) {
                    UserDefaults.standard.set(data, forKey: cacheKey)
                }
            }
        } catch {
            // Nicht kritisch
            print("TMDb fetch genre list failed: \(error)")
        }
    }
}
