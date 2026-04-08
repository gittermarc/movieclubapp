import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct SettingsSyncStatusPresentationTests {

    @Test func offlineStateWinsOverOtherStates() {
        let presentation = SettingsSyncStatusPresentation.make(
            isOffline: true,
            isSyncingNow: true,
            lastCloudSyncError: "Fehler",
            pendingCloudChangesCount: 2,
            lastCloudSyncAt: nil
        )

        #expect(presentation.statusText == "Offline")
        #expect(presentation.iconName == "wifi.slash")
        #expect(presentation.pendingText == "2")
        #expect(presentation.lastSyncText == "—")
        #expect(presentation.errorText == "Fehler")
    }

    @Test func syncingStateShownWhenOnlineWithoutOfflineOverride() {
        let presentation = SettingsSyncStatusPresentation.make(
            isOffline: false,
            isSyncingNow: true,
            lastCloudSyncError: nil,
            pendingCloudChangesCount: 0,
            lastCloudSyncAt: nil
        )

        #expect(presentation.statusText == "Synchronisiere …")
        #expect(presentation.iconName == "arrow.triangle.2.circlepath")
        #expect(presentation.pendingText == "keine")
    }

    @Test func errorStateShownWhenLastSyncErrorExists() {
        let presentation = SettingsSyncStatusPresentation.make(
            isOffline: false,
            isSyncingNow: false,
            lastCloudSyncError: " Problem ",
            pendingCloudChangesCount: 0,
            lastCloudSyncAt: nil
        )

        #expect(presentation.statusText == "Problem")
        #expect(presentation.iconName == "exclamationmark.triangle")
        #expect(presentation.errorText == "Problem")
    }

    @Test func okStateUsesInjectedRelativeTextForLastSync() {
        let now = Date(timeIntervalSince1970: 500)
        let lastSync = Date(timeIntervalSince1970: 440)

        let presentation = SettingsSyncStatusPresentation.make(
            isOffline: false,
            isSyncingNow: false,
            lastCloudSyncError: nil,
            pendingCloudChangesCount: 0,
            lastCloudSyncAt: lastSync,
            now: now,
            relativeTextProvider: { date, reference in
                #expect(date == lastSync)
                #expect(reference == now)
                return "vor 1 Min."
            }
        )

        #expect(presentation.statusText == "OK")
        #expect(presentation.iconName == "checkmark.circle")
        #expect(presentation.lastSyncText == "vor 1 Min.")
        #expect(presentation.errorText == nil)
    }
}
