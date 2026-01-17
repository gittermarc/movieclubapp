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

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
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
