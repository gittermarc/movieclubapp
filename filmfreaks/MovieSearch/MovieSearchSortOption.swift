//
//  MovieSearchSortOption.swift
//  filmfreaks
//

import Foundation

// MARK: - Sortierung (Search)

enum MovieSearchSortOption: String, CaseIterable, Identifiable, Equatable {
    case relevance = "Relevanz"
    case titleAZ = "Titel A–Z"
    case titleZA = "Titel Z–A"
    case yearNewest = "Jahr (neu → alt)"
    case yearOldest = "Jahr (alt → neu)"
    case ratingHigh = "TMDb Rating (hoch)"
    case ratingLow = "TMDb Rating (niedrig)"

    var id: Self { self }
}
