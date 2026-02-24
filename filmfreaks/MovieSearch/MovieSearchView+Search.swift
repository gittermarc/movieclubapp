//
//  MovieSearchView+Search.swift
//  filmfreaks
//

internal import SwiftUI

extension MovieSearchView {

    // MARK: - Search

    /// Cancels any running search/pagination tasks.
    ///
    /// Important: We intentionally don't reset loading flags here because a new task might
    /// already be scheduled. Callers that want to reset UI state should do so explicitly.
    func cancelSearchTasks() {
        searchTask?.cancel()
        searchTask = nil
        paginationTask?.cancel()
        paginationTask = nil
    }

    func clearSearch() {
        cancelSearchTasks()
        query = ""
        results = []
        errorMessage = nil
        currentPage = 1
        totalPages = 1
        totalResults = 0
        isLoading = false
        isLoadingMore = false
        selectedSort = .relevance
        // Verlauf bleibt erhalten
    }

    /// Starts a cancelable search task.
    ///
    /// - Cancels any existing search/pagination tasks to prevent out-of-order UI updates.
    /// - Captures the current query so it can't change mid-flight.
    /// - Uses a token to prevent stale tasks from writing state.
    func startSearch(reset: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        cancelSearchTasks()

        let token = UUID()
        activeSearchToken = token
        activePaginationToken = UUID()

        searchTask = Task {
            await performSearch(query: trimmed, reset: reset, token: token)
        }
    }

    /// Starts a cancelable pagination task.
    ///
    /// - Cancels only the previous pagination task (not the active search).
    /// - Captures query + search token so results can't be appended to the wrong search.
    func startLoadMore() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard currentPage < totalPages else { return }
        guard !isLoading else { return }
        guard !isLoadingMore else { return }

        paginationTask?.cancel()

        let paginationToken = UUID()
        activePaginationToken = paginationToken

        let nextPage = currentPage + 1
        let searchToken = activeSearchToken

        paginationTask = Task {
            await loadMore(query: trimmed, page: nextPage, searchToken: searchToken, paginationToken: paginationToken)
        }
    }

    // MARK: - Internals

    private func performSearch(query: String, reset: Bool, token: UUID) async {
        if reset {
            await MainActor.run {
                if self.activeSearchToken != token { return }
                self.results = []
                self.currentPage = 1
                self.totalPages = 1
                self.totalResults = 0
                self.selectedSort = .relevance
                self.errorMessage = nil
                self.isLoadingMore = false
            }
        }

        await MainActor.run {
            if self.activeSearchToken != token { return }
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let response = try await TMDbAPI.shared.searchMoviesPaged(query: query, page: 1)
            if Task.isCancelled { return }

            // Suchbegriff in Verlauf speichern
            SearchHistoryManager.add(query: query)
            let updatedHistory = SearchHistoryManager.load()

            await MainActor.run {
                if self.activeSearchToken != token { return }
                self.results = response.results
                self.currentPage = response.page
                self.totalPages = response.total_pages
                self.totalResults = response.total_results
                self.isLoading = false
                self.recentQueries = updatedHistory
            }
        } catch is CancellationError {
            return
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                if self.activeSearchToken != token { return }
                self.errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                if self.activeSearchToken != token { return }
                self.errorMessage = "Fehler bei der Suche. Bitte später nochmal versuchen."
                self.isLoading = false
            }
        }
    }

    private func loadMore(query: String, page: Int, searchToken: UUID, paginationToken: UUID) async {
        await MainActor.run {
            if self.activeSearchToken != searchToken { return }
            if self.activePaginationToken != paginationToken { return }
            self.isLoadingMore = true
        }

        do {
            let response = try await TMDbAPI.shared.searchMoviesPaged(query: query, page: page)
            if Task.isCancelled { return }

            await MainActor.run {
                if self.activeSearchToken != searchToken { return }
                if self.activePaginationToken != paginationToken { return }

                // Dupe-Schutz per TMDb ID
                let existingIds = Set(self.results.map { $0.id })
                let newOnes = response.results.filter { !existingIds.contains($0.id) }
                self.results.append(contentsOf: newOnes)

                self.currentPage = response.page
                self.totalPages = response.total_pages
                self.totalResults = response.total_results
                self.isLoadingMore = false
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                if self.activeSearchToken != searchToken { return }
                if self.activePaginationToken != paginationToken { return }
                self.isLoadingMore = false
                self.errorMessage = "Konnte nicht mehr laden. Bitte später nochmal versuchen."
            }
        }
    }
}
