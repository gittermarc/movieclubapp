//
//  WatchProvidersRegionPickerView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 16.01.26.
//

internal import SwiftUI

/// Länder-Picker für TMDb Watch Provider (Streaming/Rent/Buy).
/// Speichert den ISO-3166-1 Code via @AppStorage.
struct WatchProvidersRegionPickerView: View {

    @Environment(\.dismiss) private var dismiss

    @AppStorage(WatchProvidersRegionSettings.storageKey)
    private var storedRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    @State private var searchText: String = ""

    private var deviceCode: String { WatchProvidersRegionSettings.deviceRegionCode() }

    private var isAutomatic: Bool {
        storedRegionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedCode: String {
        if let effective = WatchProvidersRegionSettings.effectiveRegionCode(from: storedRegionCode) {
            return effective
        }
        return deviceCode
    }

    private var regions: [WatchProvidersRegionSettings.RegionItem] {
        let all = WatchProvidersRegionSettings.allRegions()
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }

        return all.filter { item in
            item.name.localizedCaseInsensitiveContains(q)
            || item.code.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    storedRegionCode = "" // leer == automatisch
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatisch")
                            Text("Gerät: \(WatchProvidersRegionSettings.flagEmoji(for: deviceCode)) \(WatchProvidersRegionSettings.germanDisplayName(for: deviceCode)) (")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                + Text(deviceCode).font(.caption.monospaced()).foregroundStyle(.secondary)
                                + Text(")").font(.caption).foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isAutomatic {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Empfohlen")
            } footer: {
                Text("Wenn du ein Land auswählst, zeigt die App die Streaming-Verfügbarkeit für dieses Land – unabhängig von deiner Gerätesprache.")
            }

            Section("Alle Länder") {
                ForEach(regions) { item in
                    Button {
                        storedRegionCode = item.code
                        dismiss()
                    } label: {
                        HStack {
                            Text("\(item.flag) \(item.name)")
                            Spacer()
                            Text(item.code)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            if selectedCode == item.code && !isAutomatic {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Streaming-Land")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Land oder Code suchen")
    }
}

#Preview {
    NavigationStack {
        WatchProvidersRegionPickerView()
    }
}
