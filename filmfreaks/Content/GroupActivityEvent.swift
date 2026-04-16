//
//  GroupActivityEvent.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

import Foundation

/// A small, UI-friendly event model for the group activity feed.
///
/// Important: This is *derived* from existing movie + rating data.
/// We intentionally do not store a separate Activity record in CloudKit (yet).
struct GroupActivityEvent: Identifiable, Hashable, Sendable {

    enum Kind: String, Codable, Sendable {
        case movieAdded
        case movieRated
    }

    let id: String
    let kind: Kind
    let date: Date

    let actorName: String?
    let actorId: UUID?

    let movieId: UUID
    let movieTitle: String
    let movieYear: String?
    let posterPath: String?

    /// 1–10 (optional). Only set for `.movieRated`.
    let ratingValue: Double?

    init(
        kind: Kind,
        date: Date,
        actorName: String?,
        actorId: UUID?,
        movieId: UUID,
        movieTitle: String,
        movieYear: String?,
        posterPath: String?,
        ratingValue: Double?
    ) {
        self.kind = kind
        self.date = date
        self.actorName = actorName
        self.actorId = actorId
        self.movieId = movieId
        self.movieTitle = movieTitle
        self.movieYear = movieYear
        self.posterPath = posterPath
        self.ratingValue = ratingValue

        let actorToken = actorId?.uuidString.lowercased() ?? (actorName ?? "unknown").lowercased()
        let seconds = Int(date.timeIntervalSince1970)
        self.id = "\(kind.rawValue)|\(movieId.uuidString.lowercased())|\(actorToken)|\(seconds)"
    }
}

extension GroupActivityEvent {
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
}
