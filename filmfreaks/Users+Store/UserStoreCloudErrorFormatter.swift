//
//  UserStoreCloudErrorFormatter.swift
//  filmfreaks
//
//  Created for focused sync-status testing.
//

import Foundation
import CloudKit

enum UserStoreCloudErrorFormatter {

    static func message(for error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated:
                return "iCloud nicht verfügbar – bitte iCloud-Login prüfen."
            case .networkUnavailable, .networkFailure:
                return "Netzwerkproblem – Sync wird automatisch später erneut versucht."
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return "iCloud ist gerade beschäftigt – wir versuchen es gleich nochmal."
            case .quotaExceeded:
                return "iCloud-Speicher voll – bitte Speicher prüfen."
            default:
                break
            }
        }

        return String(describing: error)
    }
}
