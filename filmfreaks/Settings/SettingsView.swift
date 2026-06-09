//
//  SettingsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 02.01.26.
//

internal import SwiftUI
internal import UIKit

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    @EnvironmentObject private var displaySettings: DisplaySettings

    @AppStorage(WatchProvidersRegionSettings.storageKey)
    private var watchProvidersRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    @State private var showClearCacheConfirm = false
    @State private var isClearingCache = false

    @State private var isLoadingCacheSize = false
    @State private var cacheSizeText: String = "—"

    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        let shortText = (short?.isEmpty == false) ? short! : "—"
        let buildText = (build?.isEmpty == false) ? build! : "—"

        if buildText == "—" { return shortText }
        if shortText == "—" { return buildText }
        return "\(shortText) (\(buildText))"
    }

    private var watchProvidersRegionLabel: String {
        let device = WatchProvidersRegionSettings.deviceRegionCode()
        let stored = watchProvidersRegionCode.trimmingCharacters(in: .whitespacesAndNewlines)

        if stored.isEmpty {
            let name = WatchProvidersRegionSettings.germanDisplayName(for: device)
            let flag = WatchProvidersRegionSettings.flagEmoji(for: device)
            return "Automatisch (\(flag) \(name))"
        }

        let effective = WatchProvidersRegionSettings.effectiveRegionCode(from: stored) ?? device
        let name = WatchProvidersRegionSettings.germanDisplayName(for: effective)
        let flag = WatchProvidersRegionSettings.flagEmoji(for: effective)
        return "\(flag) \(name) (\(effective))"
    }

    private var syncPresentation: SettingsSyncStatusPresentation {
        SettingsSyncStatusPresentation.make(
            isOffline: !networkMonitor.isConnected,
            isSyncingNow: movieStore.isSyncing || userStore.isSyncing,
            lastCloudSyncError: movieStore.lastCloudSyncError,
            pendingCloudChangesCount: movieStore.pendingCloudChangesCount,
            lastCloudSyncAt: movieStore.lastCloudSyncAt
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    SettingsSyncSectionView(presentation: syncPresentation)
                    SettingsDisplaySectionView()
                    SettingsStreamingSectionView(watchProvidersRegionLabel: watchProvidersRegionLabel)
                    SettingsCacheSectionView(
                        isLoadingCacheSize: isLoadingCacheSize,
                        cacheSizeText: cacheSizeText,
                        isClearingCache: isClearingCache,
                        onClearCache: { showClearCacheConfirm = true }
                    )
                    SettingsInfoSectionView(versionString: versionString)
                    SettingsAboutSectionView()
                }
                .navigationTitle("Einstellungen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Schließen") {
                            dismiss()
                        }
                    }
                }

                if showToast {
                    SettingsToastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showToast)
            .task {
                await refreshCacheSize()
            }
            .alert("Cache löschen?", isPresented: $showClearCacheConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Löschen", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("Löscht lokal gespeicherte Bilder und TMDb-Metadaten. Das kann nicht rückgängig gemacht werden.")
            }
        }
        .preferredColorScheme(displaySettings.preferredColorScheme)
        .tint(displaySettings.tintColor)
    }

    private func clearCache() {
        isClearingCache = true

        Task {
            await ImageCacheStore.shared.removeAll()
            await TMDbMetadataCacheFileStore().removeAll()
            URLCache.shared.removeAllCachedResponses()

            await refreshCacheSize()

            await MainActor.run {
                isClearingCache = false

                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.success)

                showToastNow("Cache gelöscht ✅")
            }
        }
    }

    private func refreshCacheSize() async {
        await MainActor.run {
            isLoadingCacheSize = true
        }

        let bytes = SettingsCacheSizeCalculator().totalLocalCacheBytes()

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let text = formatter.string(fromByteCount: Int64(bytes))

        await MainActor.run {
            cacheSizeText = text
            isLoadingCacheSize = false
        }
    }

    @MainActor
    private func showToastNow(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation {
                showToast = false
            }
        }
    }
}
