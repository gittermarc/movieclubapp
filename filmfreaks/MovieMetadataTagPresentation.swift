//
//  MovieMetadataTagPresentation.swift
//  filmfreaks
//
//  Small helper for stable metadata tag rendering.
//

import Foundation

enum MovieMetadataTagPresentation {

    static func normalizedNames(from names: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawName in names {
            let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else { continue }

            let normalizedKey = trimmedName
                .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .lowercased()

            guard seen.insert(normalizedKey).inserted else { continue }
            result.append(trimmedName)
        }

        return result
    }
}
