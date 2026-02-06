//
//  MovieTitleCandidateRanker.swift
//  filmfreaks
//

import Foundation

/// Helper zum Bewerten und Sortieren von Scan-Kandidaten (Live Text / Scanner).
/// Ziel: aus einer Liste erkannter Texte die wahrscheinlichsten Filmtitel oben anzeigen.
enum MovieTitleCandidateRanker {

    /// Liefert eine nach Qualität sortierte Kandidatenliste.
    /// - Parameters:
    ///   - recognized: Alle vom Scanner erkannten Textfragmente.
    ///   - tapped: Der Text, den der User direkt angetippt hat (wird bevorzugt).
    static func rank(recognized: [String], tapped: String) -> [String] {
        var all: [String] = []

        // Tap-Text rein (inkl. Zeilen)
        all.append(tapped)
        all.append(contentsOf: tapped.components(separatedBy: .newlines))

        // Alle erkannten Texte
        all.append(contentsOf: recognized)

        // Cleanup + dedupe
        var cleaned: [String] = all
            .map { cleanup($0) }
            .filter { !$0.isEmpty }

        // Dedupe (case-insensitive)
        var seen = Set<String>()
        cleaned = cleaned.filter { s in
            let k = s.lowercased()
            if seen.contains(k) { return false }
            seen.insert(k)
            return true
        }

        // Scoring + sort
        let scored = cleaned
            .map { ($0, score($0)) }
            .filter { $0.1 > -20 } // raus mit dem offensichtlichen Müll

        let sorted = scored
            .sorted { a, b in
                if a.1 == b.1 { return a.0.count > b.0.count }
                return a.1 > b.1
            }
            .map { $0.0 }

        // Top N – reicht in der Praxis
        return Array(sorted.prefix(12))
    }

    /// Bereinigt einen Kandidaten (Deko-Zeichen, Whitespace, zu kurze Strings).
    static func cleanup(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // häufige „Deko“-Zeichen entfernen
        t = t.replacingOccurrences(of: "•", with: " ")
        t = t.replacingOccurrences(of: "·", with: " ")
        t = t.replacingOccurrences(of: "|", with: " ")
        t = t.replacingOccurrences(of: "—", with: " ")
        t = t.replacingOccurrences(of: "–", with: " ")

        // Mehrfachspaces zu einem
        while t.contains("  ") {
            t = t.replacingOccurrences(of: "  ", with: " ")
        }

        // Trim nochmal
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: " \n\t-_:;,.()[]{}\"'"))

        // Zu kurz? Weg
        if t.count < 3 { return "" }

        return t
    }

    // MARK: - Scoring

    private static func score(_ s: String) -> Int {
        let upper = s.uppercased()

        // absolute No-Gos / Buzzwords
        let badTokens: [String] = [
            "BLU-RAY", "BLURAY", "DVD", "4K", "UHD", "ULTRA HD",
            "SPECIAL EDITION", "LIMITED EDITION", "COLLECTOR", "COLLECTORS", "STEELBOOK",
            "DIGITAL COPY", "DIGITAL", "BONUS", "FEATURES", "DISC", "DISCS",
            "DOLBY", "ATMOS", "DTS", "HDR",
            "FSK", "REGION", "UNCUT", "DIRECTOR", "DIRECTOR'S", "CUT", "EXTENDED"
        ]

        var score = 0

        // Länge – Film-Titel liegen oft irgendwo 8–40 Zeichen
        switch s.count {
        case 8...40: score += 30
        case 5...80: score += 12
        default: score -= 10
        }

        // Mehrteilig (Spaces) ist oft Titel, Einzelwort ist oft Logo/Buzzword
        if s.contains(" ") { score += 10 } else { score -= 4 }

        // Buchstabenanteil
        let letters = s.filter { $0.isLetter }.count
        if letters >= 4 { score += 10 } else { score -= 8 }

        // Ziffern-only? Nope.
        let digits = s.filter { $0.isNumber }.count
        if digits == s.count { score -= 50 }
        if digits > 0 && digits > letters { score -= 10 }

        // Bad token penalty (stark)
        if badTokens.contains(where: { upper.contains($0) }) {
            score -= 40
        }

        // sehr „shouty“ kurze Uppercase Wörter: BLU-RAY / DVD / UHD etc.
        if s.count <= 12, !s.contains(" "), s == upper {
            score -= 12
        }

        return score
    }
}
