//
//  MovieReleaseDatePresentation.swift
//  filmfreaks
//

import Foundation

enum MovieReleaseDatePresentation {
    static func preferredReleaseDateText(
        releaseDates: TMDbReleaseDatesResponse?,
        regionCode: String,
        fallbackReleaseDate: String?
    ) -> String? {
        let normalizedRegion = normalizedRegionCode(regionCode)
        let localDate = preferredReleaseDate(
            releaseDates: releaseDates,
            regionCode: normalizedRegion
        )
        return MovieMetadataPresentation.formattedReleaseDate(localDate ?? fallbackReleaseDate)
    }

    static func preferredReleaseDate(
        releaseDates: TMDbReleaseDatesResponse?,
        regionCode: String
    ) -> String? {
        let normalizedRegion = normalizedRegionCode(regionCode)
        guard let country = releaseDates?.results.first(where: {
            normalizedRegionCode($0.iso_3166_1) == normalizedRegion
        }) else {
            return nil
        }

        return country.release_dates
            .sorted { left, right in
                releaseTypePriority(left.type) < releaseTypePriority(right.type)
            }
            .map { $0.release_date.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    static func releaseTypePriority(_ type: Int) -> Int {
        switch type {
        case 3:
            return 0
        case 2:
            return 1
        case 1:
            return 2
        case 4:
            return 3
        case 5:
            return 4
        case 6:
            return 5
        default:
            return 10 + type
        }
    }

    private static func normalizedRegionCode(_ regionCode: String) -> String {
        WatchProvidersRegionSettings.normalizedRegionCode(regionCode)
        ?? regionCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
