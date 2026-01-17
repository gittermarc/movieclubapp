//
//  CloudSharingControllerView.swift
//  filmfreaks
//
//  SwiftUI wrapper for UICloudSharingController.
//

internal import SwiftUI
import CloudKit
internal import UIKit

struct CloudSharingControllerView: UIViewControllerRepresentable {

    let container: CKContainer
    let share: CKShare

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // no-op
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Cloud sharing failed: \(error)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Filmgruppe teilen"
        }
    }
}
