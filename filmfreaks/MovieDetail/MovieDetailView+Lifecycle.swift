//
//  MovieDetailView+Lifecycle.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

extension MovieDetailView {

    func handleOnAppear() {
        // Onboarding: zählt, wie oft die Detailansicht geöffnet wurde (pro Gruppe)
        OnboardingProgress.incrementDetailOpenCount(forGroupId: movie.groupId ?? movieStore.currentGroupId)

        if let existing = movie.watchedDate {
            localWatchedDate = existing
        } else {
            localWatchedDate = Date()
            if !isBacklog {
                movie.watchedDate = localWatchedDate
            }
        }

        localWatchedLocation = movie.watchedLocation ?? ""
        localSuggestedBy = movie.suggestedBy ?? ""
        loadExistingRatingForSelectedUser()

        if movie.tmdbId != nil {
            Task { await loadDetails() }
        }
    }

    func handleWatchedDateChange(_ newDate: Date) {
        guard !isBacklog else { return }
        if movie.watchedDate != newDate {
            movie.watchedDate = newDate
        }
    }

    func handleWatchedLocationChange(_ newLocation: String) {
        guard !isBacklog else { return }
        let trimmed = newLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : trimmed
        if movie.watchedLocation != newValue {
            movie.watchedLocation = newValue
        }
    }

    func handleSuggestedByChange(_ newSuggested: String) {
        let trimmed = newSuggested.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String? = trimmed.isEmpty ? nil : trimmed
        if movie.suggestedBy != newValue {
            movie.suggestedBy = newValue
        }
    }

    func handleSelectedUserChange() {
        loadExistingRatingForSelectedUser()
    }

    func handleWatchProvidersRegionChange() {
        guard movie.tmdbId != nil else { return }
        Task { await reloadWatchProvidersOnly() }
    }

    // MARK: - Options

    var locationOptions: [String] {
        var options: [String] = []

        func appendUnique(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !options.contains(trimmed) {
                options.append(trimmed)
            }
        }

        appendUnique("Heimkino")
        appendUnique("Kino")

        for name in userStore.users.map({ $0.name }) {
            appendUnique(name)
        }

        return options
    }

    var suggestedByOptions: [String] {
        userStore.users.map { $0.name }
    }
}
