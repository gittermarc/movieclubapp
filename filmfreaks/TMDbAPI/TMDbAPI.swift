//
//  TMDbAPI.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

/// Facade für TMDb (The Movie Database) HTTP API.
///
/// Das eigentliche Feature-Surface bleibt hier stabil (Public API der Klasse).
/// Die Implementierung ist in Extensions aufgeteilt:
/// - TMDbAPI+Models.swift
/// - TMDbAPI+Networking.swift
/// - TMDbAPI+Search.swift
/// - TMDbAPI+Details.swift
/// - TMDbAPI+PeopleAndMeta.swift
final class TMDbAPI: @unchecked Sendable {

    static let shared = TMDbAPI()

    /// TMDb API-Key wird zur Laufzeit aus der App-Konfiguration geladen.
    ///
    /// **Wichtig:** Ein API-Key in einer Client-App ist nie „wirklich geheim“ (er lässt sich aus dem App-Bundle extrahieren).
    /// Das hier verhindert aber, dass er offen im Source-Code / Git landet.
    ///
    /// Erwartet einen Eintrag `TMDB_API_KEY` in der Info.plist (String).
    /// Optional (z.B. Debug/CI): Environment Variable `TMDB_API_KEY`.
    ///
    /// Access-Level: `internal`, damit die Extension-Files darauf zugreifen können.
    /// Bitte außerhalb von `TMDbAPI` nicht verwenden.
    let apiKey: String

    private init() {
        self.apiKey = TMDbAPI.loadAPIKey()
    }
}

extension TMDbAPI {

    static func loadAPIKey() -> String {
        // 1) Environment (praktisch für Debug/CI)
        if let env = ProcessInfo.processInfo.environment["TMDB_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        // 2) Info.plist
        if let plist = Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String {
            let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        return ""
    }
}
