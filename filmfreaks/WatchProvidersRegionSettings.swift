//
//  WatchProvidersRegionSettings.swift
//  filmfreaks
//
//  Created by Marc Fechner on 16.01.26.
//

import Foundation

/// Zentrale Hilfsfunktionen + Persistenz-Key für die Auswahl des Landes,
/// für das TMDb Watch-Provider (Streaming/Rent/Buy) angezeigt werden.
enum WatchProvidersRegionSettings {

    /// UserDefaults Key (via @AppStorage)
    static let storageKey = "WatchProviders_RegionCode"

    /// Normalisiert einen ISO-3166-1 Ländercode.
    /// - Returns: Uppercased 2-letter code oder `nil` wenn leer/ungültig.
    static func normalizedRegionCode(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 2 else { return nil }
        return trimmed
    }

    /// Aus dem gespeicherten Wert die effektive Region ableiten.
    /// - Wenn leer -> `nil` (bedeutet: automatisch/Device-Land)
    /// - Wenn ungültig -> `nil`
    static func effectiveRegionCode(from storedValue: String) -> String? {
        let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return normalizedRegionCode(trimmed)
    }

    /// Default: aktuelles Geräte-Land. Fallback: "DE".
    static func deviceRegionCode() -> String {
        if #available(iOS 16.0, *) {
            if let region = Locale.current.region?.identifier,
               let normalized = normalizedRegionCode(region) {
                return normalized
            }
        }

        // Best-effort ohne deprecated `Locale.regionCode`
        if let code = (Locale.current as NSLocale).object(forKey: .countryCode) as? String,
           let normalized = normalizedRegionCode(code) {
            return normalized
        }

        return "DE"
    }

    /// Deutscher Anzeigename für einen ISO-Regioncode.
    static func germanDisplayName(for regionCode: String) -> String {
        let code = normalizedRegionCode(regionCode) ?? regionCode.uppercased()
        let locale = Locale(identifier: "de_DE")
        return locale.localizedString(forRegionCode: code) ?? code
    }

    /// Emoji-Flagge für einen ISO-3166-1 Code ("DE" -> 🇩🇪)
    static func flagEmoji(for regionCode: String) -> String {
        guard let code = normalizedRegionCode(regionCode) else { return "🏳️" }
        let base: UInt32 = 127397
        var scalars: [UnicodeScalar] = []
        for v in code.unicodeScalars {
            guard let scalar = UnicodeScalar(base + v.value) else { continue }
            scalars.append(scalar)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    struct RegionItem: Identifiable, Hashable {
        let code: String
        let name: String
        let flag: String
        var id: String { code }
    }

    /// Alle Länder, sortiert nach deutschem Namen.
    static func allRegions() -> [RegionItem] {
        let locale = Locale(identifier: "de_DE")

        let items = Locale.isoRegionCodes.compactMap { raw -> RegionItem? in
            guard let code = normalizedRegionCode(raw) else { return nil }
            guard let name = locale.localizedString(forRegionCode: code) else { return nil }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return RegionItem(code: code, name: trimmed, flag: flagEmoji(for: code))
        }

        return items.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
