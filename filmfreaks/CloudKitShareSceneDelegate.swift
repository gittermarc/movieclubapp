//
//  CloudKitShareSceneDelegate.swift
//  filmfreaks
//
//  Ensures CloudKit share invitations are reliably received in Scene-based apps.
//

internal import UIKit
import CloudKit
import UserNotifications

final class CloudKitShareSceneDelegate: NSObject, UIWindowSceneDelegate {

    /// Cold-start path: app is launched by tapping an iCloud share link.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { await CloudKitShareCoordinator.shared.accept(metadata) }
        }

        // Cold-start path: app launched by tapping a push notification.
        if let response = connectionOptions.notificationResponse {
            PushDeepLinkRouter.route(userInfo: response.notification.request.content.userInfo)
        }
    }

    /// Warm path: app is already running and the user accepts a share.
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { await CloudKitShareCoordinator.shared.accept(cloudKitShareMetadata) }
    }
}
