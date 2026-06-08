//
//  CloudKitTokenRecovery.swift
//  filmfreaks
//
//  Small helper for CKFetchRecordZoneChanges token recovery.
//

import Foundation
import CloudKit

struct CloudKitTokenRecoveryPlan: Equatable {
    let shouldClearToken: Bool
    let shouldRetryWithoutToken: Bool

    static let none = CloudKitTokenRecoveryPlan(
        shouldClearToken: false,
        shouldRetryWithoutToken: false
    )

    static let retryWithoutToken = CloudKitTokenRecoveryPlan(
        shouldClearToken: true,
        shouldRetryWithoutToken: true
    )
}

struct CloudKitRecoveredZoneChangesResult {
    let changes: CloudKitZoneChangesResult
    let usedPreviousToken: Bool
    let recoveredFromExpiredToken: Bool
}

enum CloudKitTokenRecovery {

    static func recoveryPlan(previousTokenWasPresent: Bool, error: Error) -> CloudKitTokenRecoveryPlan {
        guard previousTokenWasPresent, isChangeTokenExpired(error) else {
            return .none
        }
        return .retryWithoutToken
    }

    static func isChangeTokenExpired(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            if ckError.code == .changeTokenExpired {
                return true
            }

            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                return partialErrors.values.contains { isChangeTokenExpired($0) }
            }

            if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                return partialErrors.values.contains { isChangeTokenExpired($0) }
            }
        }

        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isChangeTokenExpired(underlying)
        }

        return false
    }

    static func fetchZoneChangesWithSingleRecovery(
        database: CKDatabase,
        zoneID: CKRecordZone.ID,
        previousToken: CKServerChangeToken?,
        clearToken: () -> Void
    ) async throws -> CloudKitRecoveredZoneChangesResult {
        do {
            let changes = try await CloudKitZoneChanges.fetchAllChanges(
                database: database,
                zoneID: zoneID,
                previousToken: previousToken
            )
            return CloudKitRecoveredZoneChangesResult(
                changes: changes,
                usedPreviousToken: previousToken != nil,
                recoveredFromExpiredToken: false
            )
        } catch {
            let plan = recoveryPlan(previousTokenWasPresent: previousToken != nil, error: error)
            guard plan.shouldRetryWithoutToken else {
                throw error
            }

            if plan.shouldClearToken {
                clearToken()
            }

            let changes = try await CloudKitZoneChanges.fetchAllChanges(
                database: database,
                zoneID: zoneID,
                previousToken: nil
            )
            return CloudKitRecoveredZoneChangesResult(
                changes: changes,
                usedPreviousToken: false,
                recoveredFromExpiredToken: true
            )
        }
    }
}
