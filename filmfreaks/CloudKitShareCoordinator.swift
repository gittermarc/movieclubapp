//
//  CloudKitShareCoordinator.swift
//  filmfreaks
//
//  Central handling of CloudKit share acceptance + user-facing feedback.
//

import Foundation
import CloudKit

@MainActor
final class CloudKitShareCoordinator {
    static let shared = CloudKitShareCoordinator()
    private init() {}

    func accept(_ metadata: CKShare.Metadata) async {
        ToastCenter.shared.show(
            .progress(
                title: "Einladung wird verarbeitet …",
                message: "Einen Moment – wir holen die Gruppe in deine iCloud."
            )
        )

        let container = makeContainer(from: metadata)

        do {
            let status = try await fetchAccountStatus(container: container)
            guard status == .available else {
                ToastCenter.shared.show(
                    .error(
                        title: "iCloud nicht verfügbar",
                        message: friendlyAccountStatusMessage(status)
                    ),
                    autoHideAfter: 4.0
                )
                return
            }

            try await acceptShares(container: container, metadatas: [metadata])

            // Kick refresh pipelines.
            NotificationCenter.default.post(name: .cloudKitShareAccepted, object: metadata)

            ToastCenter.shared.show(
                .success(
                    title: "Einladung angenommen",
                    message: "Die Gruppe wird jetzt synchronisiert."
                ),
                autoHideAfter: 2.4
            )
        } catch {
            let msg = friendlyCloudKitErrorMessage(error)
            ToastCenter.shared.show(
                .error(
                    title: "Einladung fehlgeschlagen",
                    message: msg
                ),
                autoHideAfter: 4.0
            )
        }
    }
}

// MARK: - Helpers

private extension CloudKitShareCoordinator {

    func makeContainer(from metadata: CKShare.Metadata) -> CKContainer {
        // `containerIdentifier` has been optional/non-optional depending on SDK.
        let identifier = (metadata.containerIdentifier as String?)
        if let id = identifier {
            return CKContainer(identifier: id)
        }
        return .default()
    }

    func fetchAccountStatus(container: CKContainer) async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { cont in
            container.accountStatus { status, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: status)
                }
            }
        }
    }

    func acceptShares(container: CKContainer, metadatas: [CKShare.Metadata]) async throws {
        try await withCheckedThrowingContinuation { cont in
            let op = CKAcceptSharesOperation(shareMetadatas: metadatas)
            op.perShareResultBlock = { _, result in
                if case .failure(let error) = result {
                    // Not every per-share failure is fatal for the whole op,
                    // but it's good to log for diagnostics.
                    print("CKAcceptSharesOperation perShareResult error: \(error)")
                }
            }
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    cont.resume(returning: ())
                case .failure(let error):
                    // If the share was already accepted before, treat it as success.
                    if let ck = error as? CKError,
                       ck.code == .alreadyShared {
                        cont.resume(returning: ())
                    } else {
                        cont.resume(throwing: error)
                    }
                }
            }
            container.add(op)
        }
    }

    func friendlyAccountStatusMessage(_ status: CKAccountStatus) -> String {
        switch status {
        case .noAccount:
            return "Du bist auf diesem Gerät nicht bei iCloud angemeldet. Bitte in den iOS-Einstellungen bei deiner Apple-ID anmelden und iCloud aktivieren – dann den Einladungslink erneut öffnen."
        case .restricted:
            return "iCloud ist auf diesem Gerät eingeschränkt (z. B. durch Bildschirmzeit/MDM). Bitte iCloud-Freigaben erlauben oder ein anderes Gerät verwenden."
        case .couldNotDetermine:
            return "Der iCloud-Status konnte gerade nicht geprüft werden. Bitte Internet prüfen und es nochmal versuchen."
        case .temporarilyUnavailable:
            return "iCloud ist gerade vorübergehend nicht erreichbar. Bitte später nochmal versuchen."
        case .available:
            return ""
        @unknown default:
            return "iCloud ist gerade nicht verfügbar. Bitte Einstellungen prüfen und erneut versuchen."
        }
    }

    func friendlyCloudKitErrorMessage(_ error: Error) -> String {
        // Be pragmatic: translate common failure modes into actionable German.
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated:
                return "Du bist nicht bei iCloud angemeldet. Bitte iCloud in den Einstellungen aktivieren und den Link erneut öffnen."
            case .networkUnavailable, .networkFailure:
                return "Keine Netzwerkverbindung. Bitte Internet prüfen und den Link erneut öffnen."
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return "iCloud ist gerade beschäftigt. Bitte in ein paar Sekunden nochmal versuchen."
            case .permissionFailure:
                return "Du hast keine Berechtigung für diese Freigabe (oder sie wurde zurückgezogen)."
            case .invalidArguments:
                return "Der Einladungslink scheint ungültig zu sein. Bitte den Einladungslink neu teilen lassen."
            default:
                break
            }
        }

        return error.localizedDescription
    }
}
