//
//  Movie.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

// MARK: - Kriterien

enum RatingCriterion: String, CaseIterable, Identifiable, Codable {
    case action = "Action"
    case suspense = "Spannung"
    case music = "Musik"
    case ambition = "Anspruch"
    case erotic = "Erotik"
    
    var id: String { rawValue }
}

// MARK: - Rating

struct Rating: Identifiable, Codable {
    var id = UUID()
    var reviewerName: String
    
    /// Sterne pro Kriterium (0–3)
    var scores: [RatingCriterion: Int]
    
    /// Optionaler Freitext-Kommentar zur Bewertung
    var comment: String? = nil
    
    /// Durchschnitt über alle Kriterien in Sternen (0–3, ggf. z.B. 2.3)
    var averageStars: Double {
        guard !scores.isEmpty else { return 0 }
        let total = scores.values.reduce(0, +)
        return Double(total) / Double(scores.count)
    }
    
    /// Normalisiert auf 0–10 Skala für Rest der App
    var averageScoreNormalizedTo10: Double {
        (averageStars / 3.0) * 10.0
    }
}

// MARK: - Movie

struct Movie: Identifiable, Codable {
    var id: UUID
    var title: String
    var year: String
    var tmdbRating: Double?
    var ratings: [Rating]
    var posterPath: String?
    var watchedDate: Date?
    var watchedLocation: String?
    var tmdbId: Int?              // NEU: TMDb-ID für spätere Detailabfragen
    var genres: [String]?     // NEU
    var suggestedBy: String? // NEU
    var cast: [String]?        // NEU: Liste von Darsteller-Namen
    var groupId: String?      // Invite-Code / Gruppen-ID
    var groupName: String?    // Anzeigename der Gruppe (optional)

    
    init(
        id: UUID = UUID(),
        title: String,
        year: String,
        tmdbRating: Double? = nil,
        ratings: [Rating] = [],
        posterPath: String? = nil,
        watchedDate: Date? = nil,
        watchedLocation: String? = nil,
        tmdbId: Int? = nil,          // NEU, mit Default
        genres: [String]? = nil,          // NEU, mit Default
        suggestedBy: String? = nil,    // NEU
        cast: [String]? = nil            //  NEU
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbRating = tmdbRating
        self.ratings = ratings
        self.posterPath = posterPath
        self.watchedDate = watchedDate
        self.watchedLocation = watchedLocation
        self.tmdbId = tmdbId        // NEU
        self.genres = genres             // NEU
        self.suggestedBy = suggestedBy   // NEU
        self.cast = cast                 // NEU
    }
}

extension Movie {
    
    static let watchedDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    /// Overall-Bewertung (0–10) über alle User
    var averageRating: Double? {
        guard !ratings.isEmpty else { return nil }
        let all = ratings.map { $0.averageScoreNormalizedTo10 }
        let total = all.reduce(0, +)
        return total / Double(all.count)
    }
    
    var watchedDateText: String? {
        guard let watchedDate else { return nil }
        return Movie.watchedDateFormatter.string(from: watchedDate)
    }
}

// MARK: - Sample-Daten nur für Previews

let sampleMovies: [Movie] = [
    Movie(
        title: "Inception",
        year: "2010",
        tmdbRating: 8.8,
        ratings: [
            Rating(
                reviewerName: "Marc",
                scores: [
                    .action: 3,
                    .suspense: 3,
                    .music: 2,
                    .erotic: 1
                ]
            )
        ],
        posterPath: nil
    ),
    Movie(
        title: "The Dark Knight",
        year: "2008",
        tmdbRating: 9.0,
        ratings: [
            Rating(
                reviewerName: "Marc",
                scores: [
                    .action: 3,
                    .suspense: 3,
                    .music: 2
                ]
            )
        ],
        posterPath: nil
    ),
    Movie(
        title: "Interstellar",
        year: "2014",
        tmdbRating: 8.6,
        ratings: [
            Rating(
                reviewerName: "Marc",
                scores: [
                    .action: 2,
                    .suspense: 2,
                    .music: 3
                ]
            )
        ],
        posterPath: nil
    )
]
