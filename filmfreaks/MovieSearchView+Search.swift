//
//  MovieSearchView+Search.swift
//  filmfreaks
//

internal import SwiftUI

extension MovieSearchView {

    // MARK: - Search

    func clearSearch() {
        query = ""
        results = []
        errorMessage = nil
        currentPage = 1
        totalPages = 1
        totalResults = 0
        selectedSort = .relevance
        // Verlauf bleibt erhalten
    }

    func performSearch(reset: Bool) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if reset {
            await MainActor.run {
                results = []
                currentPage = 1
                totalPages = 1
                totalResults = 0
                selectedSort = .relevance
                errorMessage = nil
            }
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await TMDbAPI.shared.searchMoviesPaged(query: trimmed, page: 1)

            // Suchbegriff in Verlauf speichern
            SearchHistoryManager.add(query: trimmed)
            let updatedHistory = SearchHistoryManager.load()

            await MainActor.run {
                self.results = response.results
                self.currentPage = response.page
                self.totalPages = response.total_pages
                self.totalResults = response.total_results
                self.isLoading = false
                self.recentQueries = updatedHistory
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                self.errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Fehler bei der Suche. Bitte später nochmal versuchen."
                self.isLoading = false
            }
        }
    }

    func loadMore() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard currentPage < totalPages else { return }
        guard !isLoadingMore else { return }

        isLoadingMore = true
        do {
            let nextPage = currentPage + 1
            let response = try await TMDbAPI.shared.searchMoviesPaged(query: trimmed, page: nextPage)

            await MainActor.run {
                // Dupe-Schutz per TMDb ID
                let existingIds = Set(self.results.map { $0.id })
                let newOnes = response.results.filter { !existingIds.contains($0.id) }
                self.results.append(contentsOf: newOnes)

                self.currentPage = response.page
                self.totalPages = response.total_pages
                self.totalResults = response.total_results
                self.isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingMore = false
                self.errorMessage = "Konnte nicht mehr laden. Bitte später nochmal versuchen."
            }
        }
    }
}
