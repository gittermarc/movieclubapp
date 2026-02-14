//
//  CloudKitActivitySubscriptionManager.swift
//  filmfreaks
//
//  P1: Ensure CloudKit subscriptions exist for group activity.
//
//  We create deterministic subscriptions per group so CloudKit can send
//  content-available pushes when something relevant changes.
//

import Foundation
import CloudKit

struct CloudKitActivitySubscriptionManager {

    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    // MARK: - Public API

    func ensureSubscriptions(forOwnedGroups groups: [GroupContext]) async {
        guard !groups.isEmpty else { return }
        await ensureSubscriptions(groups: groups, database: container.privateCloudDatabase)
    }

    func ensureSubscriptions(forSharedGroups groups: [GroupContext]) async {
        guard !groups.isEmpty else { return }
        await ensureSubscriptions(groups: groups, database: container.sharedCloudDatabase)
    }

    // MARK: - Internals

    private func ensureSubscriptions(groups: [GroupContext], database: CKDatabase) async {
        do {
            let existing = try await fetchAllSubscriptionIDs(in: database)

            var subsToSave: [CKSubscription] = []
            subsToSave.reserveCapacity(groups.count * 3)

            for g in groups {
                guard !g.id.isEmpty else { continue }

                // Movie: new movie added
                let movieID = subscriptionID(groupId: g.id, kind: .movie)
                if !existing.contains(movieID) {
                    subsToSave.append(makeMovieSubscription(groupId: g.id, subscriptionID: movieID))
                }

                // Rating: rating created/updated
                let ratingID = subscriptionID(groupId: g.id, kind: .rating)
                if !existing.contains(ratingID) {
                    subsToSave.append(makeRatingSubscription(groupId: g.id, subscriptionID: ratingID))
                }

                // Movie night activity: new activity event created
                let nightID = subscriptionID(groupId: g.id, kind: .movieNightActivity)
                if !existing.contains(nightID) {
                    subsToSave.append(makeMovieNightActivitySubscription(groupId: g.id, subscriptionID: nightID))
                }
            }

            guard !subsToSave.isEmpty else { return }

            // Save subscriptions (best-effort). CloudKit will deliver content-available pushes.
            for sub in subsToSave {
                _ = try await database.save(sub)
            }
        } catch {
            // Best effort: if subscriptions fail, the app still works (pull-on-foreground remains).
            print("CloudKitActivitySubscriptionManager.ensureSubscriptions error: \(error)")
        }
    }

    private func fetchAllSubscriptionIDs(in database: CKDatabase) async throws -> Set<String> {
        try await withCheckedThrowingContinuation { cont in
            // Newer SDKs: completion provides an array [CKSubscription]?
            database.fetchAllSubscriptions { subs, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let ids = Set((subs ?? []).map { $0.subscriptionID })
                cont.resume(returning: ids)
            }
        }
    }

    // MARK: - Subscription Builders

    private enum Kind: String {
        case movie
        case rating
        case movieNightActivity
    }

    private func subscriptionID(groupId: String, kind: Kind) -> String {
        "ff.act.\(groupId).\(kind.rawValue)"
    }

    private func contentAvailableNotificationInfo() -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        return info
    }

    private func makeMovieSubscription(groupId: String, subscriptionID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "groupId == %@", groupId)
        let sub = CKQuerySubscription(
            recordType: "Movie",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        sub.notificationInfo = contentAvailableNotificationInfo()
        return sub
    }

    private func makeRatingSubscription(groupId: String, subscriptionID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "groupId == %@", groupId)
        let sub = CKQuerySubscription(
            recordType: "MovieRating",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        sub.notificationInfo = contentAvailableNotificationInfo()
        return sub
    }

    private func makeMovieNightActivitySubscription(groupId: String, subscriptionID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "groupId == %@", groupId)
        let sub = CKQuerySubscription(
            recordType: "MovieNightActivity",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        sub.notificationInfo = contentAvailableNotificationInfo()
        return sub
    }
}
