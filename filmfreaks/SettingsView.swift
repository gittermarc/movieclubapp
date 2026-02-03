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

    // ✅ NEU: Land-Auswahl für Streaming-Anbieter (TMDb Watch Providers)
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

    // MARK: - Sync UI helpers

    private var isOffline: Bool {
        !networkMonitor.isConnected
    }

    private var isSyncingNow: Bool {
        movieStore.isSyncing || userStore.isSyncing
    }

    private var syncStatusText: String {
        if isOffline { return "Offline" }
        if isSyncingNow { return "Synchronisiere …" }
        if let err = movieStore.lastCloudSyncError, !err.isEmpty { return "Problem" }
        return "OK"
    }

    private var syncStatusIcon: String {
        if isOffline { return "wifi.slash" }
        if isSyncingNow { return "arrow.triangle.2.circlepath" }
        if let err = movieStore.lastCloudSyncError, !err.isEmpty { return "exclamationmark.triangle" }
        return "checkmark.circle"
    }

    private var pendingText: String {
        let c = movieStore.pendingCloudChangesCount
        return c > 0 ? String(c) : "keine"
    }

    private var lastSyncText: String {
        guard let date = movieStore.lastCloudSyncAt else { return "—" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    Section("iCloud & Sync") {
                        HStack {
                            Label("Status", systemImage: syncStatusIcon)
                            Spacer()
                            Text(syncStatusText)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Ausstehende Änderungen")
                            Spacer()
                            Text(pendingText)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Zuletzt synchronisiert")
                            Spacer()
                            Text(lastSyncText)
                                .foregroundStyle(.secondary)
                        }

                        if let err = movieStore.lastCloudSyncError, !err.isEmpty {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .accessibilityLabel("Letzter Sync-Fehler: \(err)")
                        }
                    }


                    Section("Darstellung") {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            Label("Darstellung", systemImage: "paintbrush")
                        }

                        Text("Passe Farbschema, Akzentfarbe und die Sichtbarkeit einzelner Elemente in den Listen an.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Streaming") {
                        NavigationLink {
                            WatchProvidersRegionPickerView()
                        } label: {
                            HStack {
                                Label("Streaming-Land", systemImage: "globe")
                                Spacer()
                                Text(watchProvidersRegionLabel)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(2)
                            }
                        }

                        Text("Dieses Land wird für die Streaming-Anbieter (TMDb Watch Providers) verwendet. Je Land kann die Verfügbarkeit stark variieren.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Cache") {
                        HStack {
                            Text("Cache-Größe")
                            Spacer()

                            if isLoadingCacheSize {
                                ProgressView()
                            } else {
                                Text(cacheSizeText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Cache-Größe \(cacheSizeText)")

                        Button(role: .destructive) {
                            showClearCacheConfirm = true
                        } label: {
                            HStack {
                                Label("Lokalen Cache löschen", systemImage: "trash")

                                Spacer()

                                if isClearingCache {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isClearingCache)

                        Text("Löscht den lokal gespeicherten Bild-Cache (Filmcover). Dadurch werden beim nächsten Öffnen Cover erneut geladen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Info") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(versionString)
                                .foregroundStyle(.secondary)
                        }

                        NavigationLink {
                            TMDbAttributionPrivacyView()
                        } label: {
                            Label("TMDB: Attribution & Datenschutz", systemImage: "info.circle")
                        }
                    }
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
                    toastView(message: toastMessage)
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
                Text("Der lokale Bild-Cache wird entfernt. Das kann nicht rückgängig gemacht werden.")
            }
        }
        // Wichtig: Das Settings-Sheet läuft in einem eigenen Presentation-Context.
        // Damit Farbschema-Wechsel *im Sheet* sofort greifen, erzwingen wir die gleichen Display-Settings hier.
        .preferredColorScheme(displaySettings.preferredColorScheme)
        .tint(displaySettings.tintColor)
    }

    // MARK: - Actions

    private func clearCache() {
        isClearingCache = true

        Task {
            // Unser eigener Disk+Memory-Cache (Cover)
            await ImageCacheStore.shared.removeAll()

            // System-HTTP-Cache (best effort)
            URLCache.shared.removeAllCachedResponses()

            await refreshCacheSize()

            await MainActor.run {
                isClearingCache = false

                // Haptik: success
                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.success)

                showToastNow("Cache gelöscht ✅")
            }
        }
    }

    // MARK: - Cache size

    private func refreshCacheSize() async {
        await MainActor.run {
            isLoadingCacheSize = true
        }

        let bytes = calculateImageCacheStoreBytes()

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let text = formatter.string(fromByteCount: Int64(bytes))

        await MainActor.run {
            cacheSizeText = text
            isLoadingCacheSize = false
        }
    }

    private func calculateImageCacheStoreBytes() -> Int {
        let fm = FileManager.default
        guard let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return 0
        }

        let dir = base.appendingPathComponent("ImageCacheStore", isDirectory: true)
        guard fm.fileExists(atPath: dir.path) else {
            return 0
        }

        // Sum up file sizes
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            guard values.isRegularFile == true else { continue }
            total += values.fileSize ?? 0
        }

        return total
    }

    // MARK: - Toast

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

    @ViewBuilder
    private func toastView(message: String) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                Text(message)
                    .font(.callout)
                    .lineLimit(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(radius: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
        }
    }
}
