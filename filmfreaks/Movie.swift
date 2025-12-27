//
//  Movie.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

// MARK: - Kriterien

enum RatingCriterion: String, CaseIterable, Identifiable, Codable, Hashable {
    case action = "Action"
    case suspense = "Spannung"
    case music = "Musik"
    case ambition = "Anspruch"
    case erotic = "Erotik"

    var id: String { rawValue }
}

// MARK: - Rating

struct Rating: Identifiable, Codable, Equatable {
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

// MARK: - Person Reference (Cast/Director)

struct CastMember: Identifiable, Codable, Hashable {
    /// TMDb Person ID (positiv) – eindeutig.
    /// Für Legacy-Daten können temporär negative IDs vorkommen (Migration ersetzt sie, wenn tmdbId vorhanden).
    let personId: Int
    let name: String

    var id: Int { personId }
}

// MARK: - Movie

struct Movie: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var year: String
    var tmdbRating: Double?
    var ratings: [Rating]
    var posterPath: String?
    var watchedDate: Date?
    var watchedLocation: String?
    var tmdbId: Int?

    /// Genres (Name + optional IDs für stabile Ziele)
    var genres: [String]?
    var genreIds: [Int]?

    /// Keywords (Name + optional IDs für stabile Ziele)
    var keywords: [String]?
    var keywordIds: [Int]?

    var suggestedBy: String?

    /// ✅ Cast wird als [{personId, name}] gespeichert (eindeutig, skalierbar)
    var cast: [CastMember]?

    /// ✅ Directors werden als [{personId, name}] gespeichert (für Director-Goals)
    var directors: [CastMember]?

    var groupId: String?
    var groupName: String?

    init(
        id: UUID = UUID(),
        title: String,
        year: String,
        tmdbRating: Double? = nil,
        ratings: [Rating] = [],
        posterPath: String? = nil,
        watchedDate: Date? = nil,
        watchedLocation: String? = nil,
        tmdbId: Int? = nil,
        genres: [String]? = nil,
        genreIds: [Int]? = nil,
        keywords: [String]? = nil,
        keywordIds: [Int]? = nil,
        suggestedBy: String? = nil,
        cast: [CastMember]? = nil,
        directors: [CastMember]? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbRating = tmdbRating
        self.ratings = ratings
        self.posterPath = posterPath
        self.watchedDate = watchedDate
        self.watchedLocation = watchedLocation
        self.tmdbId = tmdbId
        self.genres = genres
        self.genreIds = genreIds
        self.keywords = keywords
        self.keywordIds = keywordIds
        self.suggestedBy = suggestedBy
        self.cast = cast
        self.directors = directors
    }

    // MARK: - Codable (inkl. Migration)

    enum CodingKeys: String, CodingKey {
        case id, title, year, tmdbRating, ratings, posterPath, watchedDate, watchedLocation
        case tmdbId
        case genres, genreIds
        case keywords, keywordIds
        case suggestedBy
        case cast
        case directors
        case groupId, groupName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.year = try c.decode(String.self, forKey: .year)
        self.tmdbRating = try c.decodeIfPresent(Double.self, forKey: .tmdbRating)
        self.ratings = (try? c.decode([Rating].self, forKey: .ratings)) ?? []
        self.posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        self.watchedDate = try c.decodeIfPresent(Date.self, forKey: .watchedDate)
        self.watchedLocation = try c.decodeIfPresent(String.self, forKey: .watchedLocation)
        self.tmdbId = try c.decodeIfPresent(Int.self, forKey: .tmdbId)

        self.genres = try c.decodeIfPresent([String].self, forKey: .genres)
        self.genreIds = try c.decodeIfPresent([Int].self, forKey: .genreIds)

        self.keywords = try c.decodeIfPresent([String].self, forKey: .keywords)
        self.keywordIds = try c.decodeIfPresent([Int].self, forKey: .keywordIds)

        self.suggestedBy = try c.decodeIfPresent(String.self, forKey: .suggestedBy)
        self.groupId = try c.decodeIfPresent(String.self, forKey: .groupId)
        self.groupName = try c.decodeIfPresent(String.self, forKey: .groupName)

        // ✅ Directors (optional)
        self.directors = try c.decodeIfPresent([CastMember].self, forKey: .directors)

        // ✅ Neu: cast als [CastMember] – plus Legacy-Migration: alte Daten hatten cast: [String]
        if let castMembers = try? c.decodeIfPresent([CastMember].self, forKey: .cast) {
            self.cast = castMembers
        } else if let legacyNames = try? c.decodeIfPresent([String].self, forKey: .cast) {
            let mapped = legacyNames
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { CastMember(personId: Movie.legacyPersonId(forName: $0), name: $0) }
            self.cast = mapped.isEmpty ? nil : mapped
        } else {
            self.cast = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(year, forKey: .year)
        try c.encodeIfPresent(tmdbRating, forKey: .tmdbRating)
        try c.encode(ratings, forKey: .ratings)
        try c.encodeIfPresent(posterPath, forKey: .posterPath)
        try c.encodeIfPresent(watchedDate, forKey: .watchedDate)
        try c.encodeIfPresent(watchedLocation, forKey: .watchedLocation)
        try c.encodeIfPresent(tmdbId, forKey: .tmdbId)

        try c.encodeIfPresent(genres, forKey: .genres)
        try c.encodeIfPresent(genreIds, forKey: .genreIds)

        try c.encodeIfPresent(keywords, forKey: .keywords)
        try c.encodeIfPresent(keywordIds, forKey: .keywordIds)

        try c.encodeIfPresent(suggestedBy, forKey: .suggestedBy)
        try c.encodeIfPresent(cast, forKey: .cast)
        try c.encodeIfPresent(directors, forKey: .directors)
        try c.encodeIfPresent(groupId, forKey: .groupId)
        try c.encodeIfPresent(groupName, forKey: .groupName)
    }

    /// Stabile, negative ID für Legacy-Namen (bis wir über tmdbId echte personIds migrieren).
    private static func legacyPersonId(forName name: String) -> Int {
        let s = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var hash: UInt64 = 1469598103934665603 // FNV-1a
        for b in s.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        let v = Int(hash % UInt64(Int32.max))
        return -max(1, v)
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
