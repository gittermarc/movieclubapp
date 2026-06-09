//
//  SearchHistoryManager.swift
//  filmfreaks
//

import Foundation

// MARK: - Such-Historie (lokal per UserDefaults)

nonisolated struct SearchHistoryManager {
    private static let key = "MovieSearchHistory"
    private static let maxEntries = 15

    static func load() -> [String] {
        (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
    }

    static func save(_ entries: [String]) {
        UserDefaults.standard.set(entries, forKey: key)
    }

    static func add(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var current = load()

        // Dedupe (case-insensitive): vorhandenen Eintrag entfernen
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }

        // Neuestes vorne einfügen
        current.insert(trimmed, at: 0)

        // Begrenzen
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }

        save(current)
    }

    static func clear() {
        save([])
    }
}
