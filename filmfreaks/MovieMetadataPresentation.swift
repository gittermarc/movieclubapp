//
//  MovieMetadataPresentation.swift
//  filmfreaks
//
//  Shared lightweight helpers for detail metadata presentation.
//

import Foundation

enum MovieMetadataPresentation {

    enum PosterWidth: String {
        case w92
        case w185
        case w342
        case w500
    }

    private static let releaseDateInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let releaseDateOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    static func formattedReleaseDate(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }

        if let date = releaseDateInputFormatter.date(from: trimmedValue) {
            return releaseDateOutputFormatter.string(from: date)
        }

        return trimmedValue
    }

    static func posterURL(path: String?, width: PosterWidth) -> URL? {
        guard let path else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(width.rawValue)\(path)")
    }
}
