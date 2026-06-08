import CloudKit
import Foundation
import Testing
@testable import filmfreaks

struct CloudKitTokenRecoveryTests {

    @Test func changeTokenExpiredWithPreviousTokenRetriesWithoutToken() {
        let plan = CloudKitTokenRecovery.recoveryPlan(
            previousTokenWasPresent: true,
            error: CKError(.changeTokenExpired)
        )

        #expect(plan.shouldClearToken)
        #expect(plan.shouldRetryWithoutToken)
    }

    @Test func changeTokenExpiredWithoutPreviousTokenDoesNotRetry() {
        let plan = CloudKitTokenRecovery.recoveryPlan(
            previousTokenWasPresent: false,
            error: CKError(.changeTokenExpired)
        )

        #expect(plan == .none)
    }

    @Test func normalCloudKitErrorsAreNotTreatedAsTokenRecovery() {
        let plan = CloudKitTokenRecovery.recoveryPlan(
            previousTokenWasPresent: true,
            error: CKError(.networkUnavailable)
        )

        #expect(plan == .none)
    }

    @Test func partialFailureContainingExpiredTokenIsRecognized() {
        let recordID = CKRecord.ID(recordName: "token-test")
        let error = CKError(
            .partialFailure,
            userInfo: [CKPartialErrorsByItemIDKey: [recordID: CKError(.changeTokenExpired)]]
        )

        #expect(CloudKitTokenRecovery.isChangeTokenExpired(error))
    }
}
