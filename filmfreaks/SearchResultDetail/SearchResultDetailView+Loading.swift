//
//  SearchResultDetailView+Loading.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

extension SearchResultDetailView {

    func reloadWatchProvidersOnly() async {
        await MainActor.run {
            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProviders = []
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            let providersCountry = try await TMDbAPI.shared.fetchMovieWatchProviders(id: result.id, region: region)

            await MainActor.run {
                self.watchProvidersCountry = providersCountry
                self.watchProviders = providersCountry?.bestEffortProviders ?? []

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

    func loadDetails() async {
        await MainActor.run {
            isLoadingWatchProviders = true
            didLoadWatchProviders = false
            watchProviders = []
            watchProvidersCountry = nil
            watchProvidersLink = nil
        }

        do {
            async let detailsTask = TMDbAPI.shared.fetchMovieDetails(id: result.id)
            let region = WatchProvidersRegionSettings.effectiveRegionCode(from: watchProvidersRegionCode)
            async let providersTask = TMDbAPI.shared.fetchMovieWatchProviders(id: result.id, region: region)

            let fetched = try await detailsTask
            let providersCountry = try? await providersTask

            await MainActor.run {
                self.details = fetched
                self.isLoading = false

                // ✅ Seed Popularity aus Credits/Details (ohne /person Preload).
                if let credits = fetched.credits {
                    PersonPopularityStore.shared.ingestPopularity(fromCredits: credits.cast, crew: credits.crew)
                }

                self.watchProvidersCountry = providersCountry
                self.watchProviders = providersCountry?.bestEffortProviders ?? []
                if let linkString = providersCountry?.link {
                    self.watchProvidersLink = URL(string: linkString)
                } else {
                    self.watchProvidersLink = nil
                }
                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoading = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler beim Laden der Filmdetails."
                self.isLoading = false

                self.isLoadingWatchProviders = false
                self.didLoadWatchProviders = true
            }
        }
    }
}
