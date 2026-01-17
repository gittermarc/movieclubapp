//
//  LegacyGroupMigrationService.swift
//  filmfreaks
//
//  Migrates a legacy (public DB) group into a new CloudKit-sharing group.
//

import Foundation

enum LegacyMigrationError: LocalizedError {
    case noLegacyGroupId

    var errorDescription: String? {
        switch self {
        case .noLegacyGroupId:
            return "Kein Legacy-Invite-Code gefunden."
        }
    }
}

struct LegacyGroupMigrationService {

    func migrateLegacyGroup(
        legacyGroupId: String,
        legacyGroupName: String?,
        groupStore: CloudKitGroupStore
    ) async throws -> GroupContext {

        let displayName = (legacyGroupName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? legacyGroupName!
            : "Filmgruppe \(legacyGroupId.prefix(6))"

        // 1) Create new sharing-capable group (private DB + custom zone)
        let newGroup = try await groupStore.createGroup(name: displayName)

        let movieStore = CloudKitMovieStore()
        let ratingStore = CloudKitRatingStore()
        let userStore = CloudKitUserStore()
        let goalStore = CloudKitGoalStore.shared

        // 2) Movies
        let entries = try await movieStore.fetchMovies(forGroupId: legacyGroupId)

        // Save movies into new group
        for entry in entries {
            var m = entry.movie
            m.groupId = newGroup.id
            m.groupName = newGroup.name
            try await movieStore.save(movie: m, isBacklog: entry.isBacklog)
        }

        // 3) Ratings (per-movie)
        let movieIds = Array(Set(entries.map { $0.movie.id }))
        if !movieIds.isEmpty {
            let ratingsByMovie = try await ratingStore.fetchRatings(forGroupId: legacyGroupId, movieIds: movieIds)
            for (movieId, ratings) in ratingsByMovie {
                for r in ratings {
                    var copy = r
                    if copy.reviewerId == nil {
                        copy.reviewerId = StableID.deterministicUUID(forName: copy.reviewerName, groupId: legacyGroupId)
                    }
                    try await ratingStore.saveRating(copy, movieId: movieId, groupId: newGroup.id)
                }
            }
        }

        // 4) Members
        let members = try await userStore.fetchMembers(forGroupId: legacyGroupId)
        for m in members {
            try await userStore.upsertMember(id: m.id, name: m.name, groupId: newGroup.id)
        }

        // 5) Goals + Custom goals + decade/actor goals
        do {
            let yearGoals = try await goalStore.fetchGoals(forGroupId: legacyGroupId)
            for (year, target) in yearGoals {
                try await goalStore.saveGoal(year: year, target: target, groupId: newGroup.id)
            }
        } catch {
            // best effort
            print("Legacy migration (year goals) error: \(error)")
        }

        do {
            let custom = try await goalStore.fetchCustomGoals(forGroupId: legacyGroupId)
            try await goalStore.saveCustomGoals(custom, groupId: newGroup.id)
        } catch {
            print("Legacy migration (custom goals) error: \(error)")
        }

        do {
            let decade = try await goalStore.fetchDecadeGoals(forGroupId: legacyGroupId)
            try await goalStore.saveDecadeGoals(decade, groupId: newGroup.id)
        } catch {
            print("Legacy migration (decade goals) error: \(error)")
        }

        do {
            let actor = try await goalStore.fetchActorGoals(forGroupId: legacyGroupId)
            try await goalStore.saveActorGoals(actor, groupId: newGroup.id)
        } catch {
            print("Legacy migration (actor goals) error: \(error)")
        }

        await groupStore.refresh()
        return newGroup
    }
}
