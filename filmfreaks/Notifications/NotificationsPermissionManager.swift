//
//  NotificationsPermissionManager.swift
//  filmfreaks
//
//  P0: Minimal bootstrap for push notifications.
//  - Requests user authorization once (so local notifications can be shown later).
//  - Registers for remote notifications (needed for CloudKit subscription pushes).
//

import Foundation
internal import UIKit
import UserNotifications

@MainActor
final class NotificationsPermissionManager {

    static let shared = NotificationsPermissionManager()

    private let didRequestKey = "ff.notifications.didRequest.v1"
    private var didBootstrapThisLaunch = false

    private init() {}

    func bootstrapIfNeeded(application: UIApplication, delegate: UNUserNotificationCenterDelegate) {
        guard !didBootstrapThisLaunch else { return }
        didBootstrapThisLaunch = true

        let center = UNUserNotificationCenter.current()
        center.delegate = delegate

        // CloudKit can deliver content-available pushes regardless of alert permission,
        // but we also want to be ready for local notifications once the activity pipeline is wired.
        let didRequest = UserDefaults.standard.bool(forKey: didRequestKey)
        if didRequest {
            application.registerForRemoteNotifications()
            return
        }

        UserDefaults.standard.set(true, forKey: didRequestKey)
        Task {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                // Best effort. Even if authorization fails, CloudKit silent pushes may still work.
            }
            application.registerForRemoteNotifications()
        }
    }
}
