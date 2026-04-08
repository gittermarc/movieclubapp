import Foundation

struct SettingsSyncStatusPresentation: Equatable {
    let statusText: String
    let iconName: String
    let pendingText: String
    let lastSyncText: String
    let errorText: String?

    @MainActor
    static func make(
        isOffline: Bool,
        isSyncingNow: Bool,
        lastCloudSyncError: String?,
        pendingCloudChangesCount: Int,
        lastCloudSyncAt: Date?,
        now: Date = Date(),
        relativeTextProvider: ((Date, Date) -> String)? = nil
    ) -> SettingsSyncStatusPresentation {
        let relativeTextProvider = relativeTextProvider ?? Self.defaultRelativeText
        let trimmedError = lastCloudSyncError?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasError = trimmedError?.isEmpty == false

        let statusText: String
        let iconName: String

        if isOffline {
            statusText = "Offline"
            iconName = "wifi.slash"
        } else if isSyncingNow {
            statusText = "Synchronisiere …"
            iconName = "arrow.triangle.2.circlepath"
        } else if hasError {
            statusText = "Problem"
            iconName = "exclamationmark.triangle"
        } else {
            statusText = "OK"
            iconName = "checkmark.circle"
        }

        let pendingText = pendingCloudChangesCount > 0 ? String(pendingCloudChangesCount) : "keine"
        let lastSyncText = lastCloudSyncAt.map { relativeTextProvider($0, now) } ?? "—"

        return SettingsSyncStatusPresentation(
            statusText: statusText,
            iconName: iconName,
            pendingText: pendingText,
            lastSyncText: lastSyncText,
            errorText: hasError ? trimmedError : nil
        )
    }

    private static func defaultRelativeText(for date: Date, relativeTo now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
