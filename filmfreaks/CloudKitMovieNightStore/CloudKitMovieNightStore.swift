//
//  CloudKitMovieNightStore.swift
//  filmfreaks
//
//  Phase 3 (Movie Nights): Cloud read support.
//

import Foundation
import CloudKit

/// Kapselt alle CloudKit-Zugriffe fuer Filmabende.
///
/// Phase 3: Read-only (Zone-Changes + Snapshot).
/// Phase 4: Writes/Deletes via debounced + batched Upload-Queue.
struct CloudKitMovieNightStore {

    // MARK: - CloudKit Setup

    let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Schema

    // Record Types
    let eventRecordType = "MovieNightEvent"
    let responseRecordType = "MovieNightResponse"
    let activityRecordType = "MovieNightActivity"

    // Common keys
    let groupIdKey = "groupId"

    // Event keys
    let proposedStartKey = "proposedStart"
    let createdAtKey = "createdAt"
    let updatedAtKey = "updatedAt"
    let proposerUserIdKey = "proposerUserId"
    let proposerNameKey = "proposerName"
    let movieIdKey = "movieId"
    let movieTitleKey = "movieTitle"
    let movieYearKey = "movieYear"
    let moviePosterPathKey = "moviePosterPath"
    let movieTmdbIdKey = "movieTmdbId"
    let noteKey = "note"
    let statusKey = "status"

    // Response keys
    let eventIdKey = "eventId"
    let userIdKey = "userId"
    let userNameKey = "userName"
    let decisionKey = "decision"
    let respondedAtKey = "respondedAt"

    // Activity keys
    let kindKey = "kind"
    let eventStartKey = "eventStart"
    let actorUserIdKey = "actorUserId"
    let actorNameKey = "actorName"
    let newStatusKey = "newStatus"
}
