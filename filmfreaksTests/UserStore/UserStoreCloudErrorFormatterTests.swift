import CloudKit
import Foundation
import Testing
@testable import filmfreaks

struct UserStoreCloudErrorFormatterTests {

    @Test func notAuthenticatedMapsToHelpfulMessage() {
        let message = UserStoreCloudErrorFormatter.message(for: CKError(.notAuthenticated))
        #expect(message == "iCloud nicht verfügbar – bitte iCloud-Login prüfen.")
    }

    @Test func networkErrorsShareRetryMessage() {
        let unavailable = UserStoreCloudErrorFormatter.message(for: CKError(.networkUnavailable))
        let failure = UserStoreCloudErrorFormatter.message(for: CKError(.networkFailure))

        #expect(unavailable == "Netzwerkproblem – Sync wird automatisch später erneut versucht.")
        #expect(failure == unavailable)
    }

    @Test func busyErrorsShareBusyMessage() {
        let serviceUnavailable = UserStoreCloudErrorFormatter.message(for: CKError(.serviceUnavailable))
        let requestRateLimited = UserStoreCloudErrorFormatter.message(for: CKError(.requestRateLimited))
        let zoneBusy = UserStoreCloudErrorFormatter.message(for: CKError(.zoneBusy))

        #expect(serviceUnavailable == "iCloud ist gerade beschäftigt – wir versuchen es gleich nochmal.")
        #expect(requestRateLimited == serviceUnavailable)
        #expect(zoneBusy == serviceUnavailable)
    }

    @Test func quotaExceededMapsToStorageMessage() {
        let message = UserStoreCloudErrorFormatter.message(for: CKError(.quotaExceeded))
        #expect(message == "iCloud-Speicher voll – bitte Speicher prüfen.")
    }

    @Test func unknownErrorsFallBackToDescription() {
        struct SampleError: Error, CustomStringConvertible {
            var description: String { "sample-error" }
        }

        let message = UserStoreCloudErrorFormatter.message(for: SampleError())
        #expect(message == "sample-error")
    }
}
