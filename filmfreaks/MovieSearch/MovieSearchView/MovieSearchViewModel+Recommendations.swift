import Foundation

extension MovieSearchViewModel {

    func loadDiscoveryIfNeeded(
        query: String,
        isSearchFieldFocused: Bool,
        localWatchedKeys: Set<String>,
        localBacklogKeys: Set<String>,
        regionCode: String?,
        force: Bool = false
    ) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return }
        guard !isSearchFieldFocused else { return }
        guard results.isEmpty && !isLoading else { return }
        guard !isLoadingDiscovery || force else { return }

        if force {
            discoveryTask?.cancel()
            discoveryRefreshTask?.cancel()
        }

        let token = UUID()
        activeDiscoveryToken = token
        isLoadingDiscovery = true
        discoveryError = nil

        let request = MovieDiscoveryRequest(
            existingWatched: existingWatched,
            existingBacklog: existingBacklog,
            localWatchedKeys: localWatchedKeys,
            localBacklogKeys: localBacklogKeys,
            regionCode: regionCode
        )

        let result = await dependencies.loadDiscoveryShelves(request, force)
        guard activeDiscoveryToken == token else { return }
        guard !Task.isCancelled else { return }

        discoveryShelves = result.shelves
        isLoadingDiscovery = false
        discoveryError = result.shelves.contains(where: { $0.hasVisibleContent })
            ? nil
            : result.shelves.compactMap(\.errorMessage).first

        if result.usedStaleCache && !force {
            scheduleDiscoveryRevalidation(
                request: request,
                token: token,
                localWatchedKeys: localWatchedKeys,
                localBacklogKeys: localBacklogKeys
            )
        }
    }

    func loadRecommendationsIfNeeded(
        query: String,
        isSearchFieldFocused: Bool,
        localWatchedKeys: Set<String>,
        localBacklogKeys: Set<String>,
        regionCode: String? = nil,
        force: Bool = false
    ) async {
        await loadDiscoveryIfNeeded(
            query: query,
            isSearchFieldFocused: isSearchFieldFocused,
            localWatchedKeys: localWatchedKeys,
            localBacklogKeys: localBacklogKeys,
            regionCode: regionCode,
            force: force
        )
    }

    private func scheduleDiscoveryRevalidation(
        request: MovieDiscoveryRequest,
        token: UUID,
        localWatchedKeys: Set<String>,
        localBacklogKeys: Set<String>
    ) {
        discoveryRefreshTask?.cancel()
        discoveryRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let refreshed = await self.dependencies.loadDiscoveryShelves(request, true)
            guard self.activeDiscoveryToken == token else { return }
            guard !Task.isCancelled else { return }
            self.discoveryShelves = refreshed.shelves
            self.discoveryError = refreshed.shelves.contains(where: { $0.hasVisibleContent })
                ? nil
                : refreshed.shelves.compactMap(\.errorMessage).first
        }
    }
}
