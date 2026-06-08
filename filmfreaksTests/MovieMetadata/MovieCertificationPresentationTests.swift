import Testing
@testable import filmfreaks

struct MovieCertificationPresentationTests {

    @Test func germanCertificationIsFormattedAsFSK() {
        let releaseDates = makeReleaseDates(
            regionCode: "DE",
            releases: [
                TMDbReleaseDate(
                    certification: "12",
                    descriptors: nil,
                    iso_639_1: nil,
                    note: nil,
                    release_date: "2016-11-10T00:00:00.000Z",
                    type: 3
                )
            ]
        )

        let presentation = MovieCertificationPresentation.make(
            releaseDates: releaseDates,
            regionCode: "de"
        )

        #expect(presentation?.text == "FSK 12")
        #expect(presentation?.regionCode == "DE")
    }

    @Test func emptyCertificationIsIgnored() {
        let releaseDates = makeReleaseDates(
            regionCode: "DE",
            releases: [
                TMDbReleaseDate(
                    certification: "   ",
                    descriptors: nil,
                    iso_639_1: nil,
                    note: nil,
                    release_date: "2016-11-10T00:00:00.000Z",
                    type: 3
                )
            ]
        )

        let presentation = MovieCertificationPresentation.make(
            releaseDates: releaseDates,
            regionCode: "DE"
        )

        #expect(presentation == nil)
    }

    @Test func regionWithoutCertificationDoesNotFallbackToUS() {
        let releaseDates = TMDbReleaseDatesResponse(
            results: [
                TMDbReleaseDatesCountry(
                    iso_3166_1: "US",
                    release_dates: [
                        TMDbReleaseDate(
                            certification: "PG-13",
                            descriptors: nil,
                            iso_639_1: nil,
                            note: nil,
                            release_date: "2016-11-11T00:00:00.000Z",
                            type: 3
                        )
                    ]
                )
            ]
        )

        let presentation = MovieCertificationPresentation.make(
            releaseDates: releaseDates,
            regionCode: "DE"
        )

        #expect(presentation == nil)
    }

    @Test func nonGermanCertificationKeepsRegionContext() {
        let releaseDates = makeReleaseDates(
            regionCode: "US",
            releases: [
                TMDbReleaseDate(
                    certification: "PG-13",
                    descriptors: nil,
                    iso_639_1: nil,
                    note: nil,
                    release_date: "2016-11-11T00:00:00.000Z",
                    type: 3
                )
            ]
        )

        let presentation = MovieCertificationPresentation.make(
            releaseDates: releaseDates,
            regionCode: "US"
        )

        #expect(presentation?.text == "US PG-13")
    }

    @Test func theatricalCertificationWinsOverDigitalCertification() {
        let releaseDates = makeReleaseDates(
            regionCode: "DE",
            releases: [
                TMDbReleaseDate(
                    certification: "16",
                    descriptors: nil,
                    iso_639_1: nil,
                    note: nil,
                    release_date: "2016-12-01T00:00:00.000Z",
                    type: 4
                ),
                TMDbReleaseDate(
                    certification: "12",
                    descriptors: nil,
                    iso_639_1: nil,
                    note: nil,
                    release_date: "2016-11-10T00:00:00.000Z",
                    type: 3
                )
            ]
        )

        let presentation = MovieCertificationPresentation.make(
            releaseDates: releaseDates,
            regionCode: "DE"
        )

        #expect(presentation?.text == "FSK 12")
    }

    private func makeReleaseDates(
        regionCode: String,
        releases: [TMDbReleaseDate]
    ) -> TMDbReleaseDatesResponse {
        TMDbReleaseDatesResponse(
            results: [
                TMDbReleaseDatesCountry(
                    iso_3166_1: regionCode,
                    release_dates: releases
                )
            ]
        )
    }
}
