//
//  CloudKitShareSceneDelegate.swift
//  filmfreaks
//
//  Ensures CloudKit share acceptance works reliably in scene-based (SwiftUI) apps.
//

internal import UIKit
import CloudKit

/// Scene-based callback for CloudKit share acceptance.
///
/// Note: On modern iOS versions, CloudKit may call this method instead of
/// `UIApplicationDelegate.application(_:userDidAcceptCloudKitShareWith:)`.
final class CloudKitShareSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Cold start case: when the app is launched from a share acceptance,
        // the metadata may arrive via the connection options.
        if let metadata = connectionOptions.cloudKitShareMetadata {
            CloudKitShareAcceptance.accept(metadata)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        CloudKitShareAcceptance.accept(cloudKitShareMetadata)
    }
}

/// Shared implementation used by both AppDelegate and SceneDelegate entry points.
enum CloudKitShareAcceptance {
    static func accept(_ cloudKitShareMetadata: CKShare.Metadata) {
        // `containerIdentifier` has been optional/non-optional depending on SDK.
        // Casting to `String?` compiles in both cases.
        let identifier = (cloudKitShareMetadata.containerIdentifier as String?)
        let container: CKContainer = {
            if let id = identifier {
                return CKContainer(identifier: id)
            }
            return .default()
        }()

        let op = CKAcceptSharesOperation(shareMetadatas: [cloudKitShareMetadata])
        op.perShareResultBlock = { metadata, result in
            switch result {
            case .success:
                NotificationCenter.default.post(name: .cloudKitShareAccepted, object: metadata)
            case .failure(let error):
                print("CKAcceptSharesOperation perShareResult error: \(error)")
            }
        }
        op.acceptSharesResultBlock = { result in
            if case .failure(let error) = result {
                print("CKAcceptSharesOperation error: \(error)")
            }
        }
        container.add(op)
    }
}
