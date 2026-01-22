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
    @Binding var share: CKShare
    var onError: ((Error) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(share: $share, onError: onError)
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
        private let share: Binding<CKShare>
        private let onError: ((Error) -> Void)?

        init(share: Binding<CKShare>, onError: ((Error) -> Void)?) {
            self.share = share
            self.onError = onError
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            onError?(error)
            print("Cloud sharing failed: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            if let updated = csc.share {
                share.wrappedValue = updated
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            if let updated = csc.share {
                share.wrappedValue = updated
            }
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Filmgruppe teilen"
        }
    }
}
