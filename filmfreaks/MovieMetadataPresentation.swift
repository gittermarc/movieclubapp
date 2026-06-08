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

    enum BackdropWidth: String {
        case w300
        case w780
        case w1280
        case original
    }

    enum ImageWidth: String {
        case w92
        case w185
        case w300
        case w342
        case w500
        case w780
        case w1280
        case original
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
        imageURL(path: path, width: width.rawValue)
    }

    static func backdropURL(path: String?, width: BackdropWidth) -> URL? {
        imageURL(path: path, width: width.rawValue)
    }

    static func imageURL(path: String?, width: ImageWidth) -> URL? {
        imageURL(path: path, width: width.rawValue)
    }

    static func bestBackdropURL(
        backdropPath: String?,
        images: TMDbMovieImagesResponse?,
        width: BackdropWidth
    ) -> URL? {
        if let url = backdropURL(path: backdropPath, width: width) {
            return url
        }

        let bestImage = images?.backdrops
            .filter { normalizedImagePath($0.file_path) != nil }
            .sorted(by: backdropSort)
            .first

        return backdropURL(path: bestImage?.file_path, width: width)
    }

    static func trailerPreviewURL(
        backdropPath: String?,
        images: TMDbMovieImagesResponse?,
        posterPath: String?
    ) -> URL? {
        bestBackdropURL(
            backdropPath: backdropPath,
            images: images,
            width: .w780
        ) ?? posterURL(path: posterPath, width: .w500)
    }

    private static func imageURL(path: String?, width: String) -> URL? {
        guard let normalizedPath = normalizedImagePath(path) else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(width)\(normalizedPath)")
    }

    private static func normalizedImagePath(_ path: String?) -> String? {
        guard let path else { return nil }
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }
        return trimmedPath.hasPrefix("/") ? trimmedPath : "/\(trimmedPath)"
    }

    private static func backdropSort(_ left: TMDbImage, _ right: TMDbImage) -> Bool {
        let leftVoteCount = left.vote_count ?? 0
        let rightVoteCount = right.vote_count ?? 0
        if leftVoteCount != rightVoteCount {
            return leftVoteCount > rightVoteCount
        }

        let leftVoteAverage = left.vote_average ?? 0
        let rightVoteAverage = right.vote_average ?? 0
        if leftVoteAverage != rightVoteAverage {
            return leftVoteAverage > rightVoteAverage
        }

        let leftWidth = left.width ?? 0
        let rightWidth = right.width ?? 0
        if leftWidth != rightWidth {
            return leftWidth > rightWidth
        }

        let leftHeight = left.height ?? 0
        let rightHeight = right.height ?? 0
        return leftHeight > rightHeight
    }
}
