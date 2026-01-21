//
//  CloudKitShareAppDelegate.swift
//  filmfreaks
//
//  Handles CloudKit share invitations accepted by the user.
//

internal import UIKit
import CloudKit

extension Notification.Name {
    static let cloudKitShareAccepted = Notification.Name("CloudKitShareAccepted")
}

final class CloudKitShareAppDelegate: NSObject, UIApplicationDelegate {

    /// SwiftUI apps use scenes. Starting with iOS 13 (and increasingly in newer iOS versions),
    /// CloudKit delivers share-acceptance callbacks to the window scene delegate.
    /// We install a scene delegate so `windowScene(_:userDidAcceptCloudKitShareWith:)` is reliably called.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = CloudKitShareSceneDelegate.self
        return sceneConfig
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CloudKitShareAcceptance.accept(cloudKitShareMetadata)
    }
}
