internal import SwiftUI

struct SettingsSyncSectionView: View {
    let presentation: SettingsSyncStatusPresentation

    var body: some View {
        Section("iCloud & Sync") {
            HStack {
                Label("Status", systemImage: presentation.iconName)
                Spacer()
                Text(presentation.statusText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Ausstehende Änderungen")
                Spacer()
                Text(presentation.pendingText)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Zuletzt synchronisiert")
                Spacer()
                Text(presentation.lastSyncText)
                    .foregroundStyle(.secondary)
            }

            if let errorText = presentation.errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .accessibilityLabel("Letzter Sync-Fehler: \(errorText)")
            }
        }
    }
}

struct SettingsDisplaySectionView: View {
    var body: some View {
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
    }
}

struct SettingsStreamingSectionView: View {
    let watchProvidersRegionLabel: String

    var body: some View {
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
    }
}

struct SettingsCacheSectionView: View {
    let isLoadingCacheSize: Bool
    let cacheSizeText: String
    let isClearingCache: Bool
    let onClearCache: () -> Void

    var body: some View {
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

            Button(role: .destructive, action: onClearCache) {
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
    }
}

struct SettingsInfoSectionView: View {
    let versionString: String

    var body: some View {
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
}

struct SettingsToastView: View {
    let message: String

    var body: some View {
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
