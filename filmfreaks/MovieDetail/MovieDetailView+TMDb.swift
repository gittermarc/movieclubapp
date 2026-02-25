//
//  MovieDetailView+TMDb.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

extension MovieDetailView {

    // MARK: - TMDb Load

    func loadDetails() async {
        guard let id = movie.tmdbId else { return }

        await MainActor.run {
            isLoadingDetails = true
            detailsError = nil

            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            async let detailsTask = TMDbAPI.shared.fetchMovieDetails(id: id)
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            async let providersTask = TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)

            let fetched = try await detailsTask
            let providersCountry = try? await providersTask

            await MainActor.run {
                self.details = fetched

                // ✅ Seed Popularity aus Credits/Details (ohne /person Preload).
                if let credits = fetched.credits {
                    PersonPopularityStore.shared.ingestPopularity(fromCredits: credits.cast, crew: credits.crew)
                }

                let genreNames = fetched.genres?
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let genreIds = fetched.genres?.map { $0.id }

                let keywordNames = fetched.keywords?.allKeywords
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let keywordIds = fetched.keywords?.allKeywords.map { $0.id }

                // Cast als {personId, name} persistieren
                let castMembers = fetched.credits?.cast
                    .prefix(30)
                    .map {
                        CastMember(
                            personId: $0.id,
                            name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .filter { !$0.name.isEmpty }

                // Directors als {personId, name} persistieren (für Director-Goals)
                let directorMembers = fetched.credits?.crew
                    .filter { ($0.job ?? "").lowercased() == "director" }
                    .map {
                        CastMember(
                            personId: $0.id,
                            name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    .filter { !$0.name.isEmpty }

                if let genreNames, !genreNames.isEmpty {
                    self.movie.genres = genreNames
                }

                if let genreIds, !genreIds.isEmpty {
                    self.movie.genreIds = genreIds
                }

                if let keywordNames, !keywordNames.isEmpty {
                    self.movie.keywords = keywordNames
                }

                if let keywordIds, !keywordIds.isEmpty {
                    self.movie.keywordIds = keywordIds
                }

                if let castMembers, !castMembers.isEmpty {
                    self.movie.cast = castMembers
                }

                if let directorMembers, !directorMembers.isEmpty {
                    self.movie.directors = directorMembers
                }

                self.movie.tmdbRating = fetched.vote_average
                if let posterPath = fetched.poster_path {
                    self.movie.posterPath = posterPath
                }

                // Watch Providers
                self.watchProvidersCountry = providersCountry
                if let linkString = providersCountry?.link {
                    self.watchProvidersLink = URL(string: linkString)
                } else {
                    self.watchProvidersLink = nil
                }
                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true

                self.isLoadingDetails = false
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.detailsError = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoadingDetails = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch {
            await MainActor.run {
                self.detailsError = "Fehler beim Laden der Filmdetails."
                self.isLoadingDetails = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        }
    }

    func reloadWatchProvidersOnly() async {
        guard let id = movie.tmdbId else { return }

        await MainActor.run {
            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            let providersCountry = try await TMDbAPI.shared.fetchMovieWatchProviders(id: id, region: region)

            await MainActor.run {
                self.watchProvidersCountry = providersCountry
                if let linkString = providersCountry?.link {
                    self.watchProvidersLink = URL(string: linkString)
                } else {
                    self.watchProvidersLink = nil
                }

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch {
            await MainActor.run {
                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        }
    }
}
