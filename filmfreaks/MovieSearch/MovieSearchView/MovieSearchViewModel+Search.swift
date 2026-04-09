import Foundation

extension MovieSearchViewModel {

    func startSearch(query: String, reset: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        cancelTasks()

        let token = UUID()
        activeSearchToken = token
        activePaginationToken = UUID()

        searchTask = Task { @MainActor [weak self] in
            await self?.performSearch(query: trimmed, reset: reset, token: token)
        }
    }

    func startLoadMore(query: String) {
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

        paginationTask = Task { @MainActor [weak self] in
            await self?.loadMore(
                query: trimmed,
                page: nextPage,
                searchToken: searchToken,
                paginationToken: paginationToken
            )
        }
    }

    private func performSearch(query: String, reset: Bool, token: UUID) async {
        if reset {
            guard activeSearchToken == token else { return }
            results = []
            currentPage = 1
            totalPages = 1
            totalResults = 0
            errorMessage = nil
            isLoadingMore = false
        }

        guard activeSearchToken == token else { return }
        isLoading = true
        errorMessage = nil

        do {
            let response = try await dependencies.searchMoviesPaged(query, 1)
            if Task.isCancelled { return }

            dependencies.addRecentQuery(query)
            let updatedHistory = dependencies.loadRecentQueries()

            guard activeSearchToken == token else { return }
            results = response.results
            currentPage = response.page
            totalPages = response.total_pages
            totalResults = response.total_results
            isLoading = false
            recentQueries = updatedHistory
        } catch is CancellationError {
            return
        } catch TMDbError.missingAPIKey {
            guard activeSearchToken == token else { return }
            errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
            isLoading = false
        } catch {
            guard activeSearchToken == token else { return }
            errorMessage = "Fehler bei der Suche. Bitte später nochmal versuchen."
            isLoading = false
        }
    }

    private func loadMore(query: String, page: Int, searchToken: UUID, paginationToken: UUID) async {
        guard activeSearchToken == searchToken else { return }
        guard activePaginationToken == paginationToken else { return }
        isLoadingMore = true

        do {
            let response = try await dependencies.searchMoviesPaged(query, page)
            if Task.isCancelled { return }

            guard activeSearchToken == searchToken else { return }
            guard activePaginationToken == paginationToken else { return }

            let existingIds = Set(results.map(\.id))
            let newOnes = response.results.filter { !existingIds.contains($0.id) }
            results.append(contentsOf: newOnes)

            currentPage = response.page
            totalPages = response.total_pages
            totalResults = response.total_results
            isLoadingMore = false
        } catch is CancellationError {
            return
        } catch {
            guard activeSearchToken == searchToken else { return }
            guard activePaginationToken == paginationToken else { return }
            isLoadingMore = false
            errorMessage = "Konnte nicht mehr laden. Bitte später nochmal versuchen."
        }
    }
}
