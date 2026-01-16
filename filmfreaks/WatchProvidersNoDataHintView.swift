//
//  WatchProvidersNoDataHintView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 16.01.26.
//

internal import SwiftUI

/// Empty-State, wenn TMDb für das aktuell ausgewählte Land keine Watch-Provider meldet.
/// Zeigt einen Hinweis + optionalen Button, um ein anderes Land auszuwählen.
struct WatchProvidersNoDataHintView: View {

    let regionCode: String
    let isAutomatic: Bool
    let onShowOtherCountries: () -> Void

    private var normalizedCode: String {
        WatchProvidersRegionSettings.normalizedRegionCode(regionCode) ?? regionCode.uppercased()
    }

    private var flag: String {
        WatchProvidersRegionSettings.flagEmoji(for: normalizedCode)
    }

    private var name: String {
        WatchProvidersRegionSettings.germanDisplayName(for: normalizedCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Für \(flag) keine Anbieter gemeldet.")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 6) {
                Text("\(name) (")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(normalizedCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isAutomatic {
                    Text("• Automatisch (Gerät)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("TMDb hat für dieses Land gerade keine Streaming-/Kauf-Infos hinterlegt. Du kannst optional ein anderes Land auswählen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onShowOtherCountries()
            } label: {
                Label("Andere Länder anzeigen", systemImage: "globe")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }
}

#Preview {
    WatchProvidersNoDataHintView(regionCode: "DE", isAutomatic: false) {
        print("show picker")
    }
    .padding()
}
