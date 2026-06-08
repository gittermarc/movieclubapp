//
//  MovieCertificationPresentation.swift
//  filmfreaks
//

import Foundation

struct MovieCertificationPresentation: Equatable, Sendable {
    let regionCode: String
    let rawCertification: String
    let text: String

    static func make(
        releaseDates: TMDbReleaseDatesResponse?,
        regionCode: String
    ) -> MovieCertificationPresentation? {
        let normalizedRegion = normalizedRegionCode(regionCode)
        guard let certification = preferredCertification(
            releaseDates: releaseDates,
            regionCode: normalizedRegion
        ) else {
            return nil
        }

        let displayText = displayText(
            certification: certification,
            regionCode: normalizedRegion
        )

        return MovieCertificationPresentation(
            regionCode: normalizedRegion,
            rawCertification: certification,
            text: displayText
        )
    }

    static func preferredCertification(
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
            .compactMap { releaseDate in
                let certification = releaseDate.certification.trimmingCharacters(in: .whitespacesAndNewlines)
                return certification.isEmpty ? nil : certification
            }
            .first
    }

    static func displayText(
        certification: String,
        regionCode: String
    ) -> String {
        let trimmedCertification = certification.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRegion = normalizedRegionCode(regionCode)

        guard normalizedRegion == "DE" else {
            return "\(normalizedRegion) \(trimmedCertification)"
        }

        let uppercased = trimmedCertification.uppercased()
        if uppercased.hasPrefix("FSK") {
            return trimmedCertification
        }

        return "FSK \(trimmedCertification)"
    }

    private static func releaseTypePriority(_ type: Int) -> Int {
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
