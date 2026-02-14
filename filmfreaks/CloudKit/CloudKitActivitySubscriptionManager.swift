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
            let existing = try await fetchAllSubscriptionsByID(in: database)

            var subsToSave: [CKSubscription] = []
            subsToSave.reserveCapacity(groups.count * 3)

            for g in groups {
                guard !g.id.isEmpty else { continue }
                let groupName = g.name.trimmingCharacters(in: .whitespacesAndNewlines)

                // Movie: new movie added
                let movieID = subscriptionID(groupId: g.id, kind: .movie)
                if shouldUpsertSubscription(existing[movieID]) {
                    subsToSave.append(makeMovieSubscription(groupId: g.id, groupName: groupName, subscriptionID: movieID))
                }

                // Rating: rating created/updated
                let ratingID = subscriptionID(groupId: g.id, kind: .rating)
                if shouldUpsertSubscription(existing[ratingID]) {
                    subsToSave.append(makeRatingSubscription(groupId: g.id, groupName: groupName, subscriptionID: ratingID))
                }

                // Movie night activity: new activity event created
                let nightID = subscriptionID(groupId: g.id, kind: .movieNightActivity)
                if shouldUpsertSubscription(existing[nightID]) {
                    subsToSave.append(makeMovieNightActivitySubscription(groupId: g.id, groupName: groupName, subscriptionID: nightID))
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

    private func fetchAllSubscriptionsByID(in database: CKDatabase) async throws -> [String: CKSubscription] {
        try await withCheckedThrowingContinuation { cont in
            // Newer SDKs: completion provides an array [CKSubscription]?
            database.fetchAllSubscriptions { subs, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let map = Dictionary(uniqueKeysWithValues: (subs ?? []).map { ($0.subscriptionID, $0) })
                cont.resume(returning: map)
            }
        }
    }

    private func shouldUpsertSubscription(_ existing: CKSubscription?) -> Bool {
        // Create if missing.
        guard let existing else { return true }

        // Upgrade older "silent only" subscriptions (alert/sound/badge absent).
        // With alert+sound CloudKit delivers visible notifications reliably.
        let info = existing.notificationInfo
        let hasAlert = (info?.alertBody?.isEmpty == false)
        let hasSound = (info?.soundName?.isEmpty == false)
        let hasBadge = (info?.shouldBadge == true)
        return !(hasAlert && hasSound && hasBadge)
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
        // NOTE:
        // - shouldSendContentAvailable = true enables background delivery (silent push).
        // - Adding alert/sound/badge makes CloudKit deliver a *visible* notification,
        //   which is far more reliable than relying on background wake + local notifications.
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        return info
    }

    private func visibleActivityNotificationInfo(groupName: String) -> CKSubscription.NotificationInfo {
        let info = contentAvailableNotificationInfo()

        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            info.alertBody = "Neue Gruppenaktivität"
        } else {
            info.alertBody = "Neue Aktivität in „\(name)“"
        }

        info.soundName = "default"
        info.shouldBadge = true
        return info
    }

    private func makeMovieSubscription(groupId: String, groupName: String, subscriptionID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "groupId == %@", groupId)
        let sub = CKQuerySubscription(
            recordType: "Movie",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        sub.notificationInfo = visibleActivityNotificationInfo(groupName: groupName)
        return sub
    }

    private func makeRatingSubscription(groupId: String, groupName: String, subscriptionID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "groupId == %@", groupId)
        let sub = CKQuerySubscription(
            recordType: "MovieRating",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        sub.notificationInfo = visibleActivityNotificationInfo(groupName: groupName)
        return sub
    }

    private func makeMovieNightActivitySubscription(groupId: String, groupName: String, subscriptionID: String) -> CKQuerySubscription {
        let predicate = NSPredicate(format: "groupId == %@", groupId)
        let sub = CKQuerySubscription(
            recordType: "MovieNightActivity",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        sub.notificationInfo = visibleActivityNotificationInfo(groupName: groupName)
        return sub
    }
}
