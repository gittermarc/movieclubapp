import Testing
@testable import filmfreaks

struct MovieFactsPresentationTests {

    @Test func releaseDateSelectionPrefersLocalTheatricalRelease() {
        let details = makeDetails(
            releaseDates: TMDbReleaseDatesResponse(
                results: [
                    TMDbReleaseDatesCountry(
                        iso_3166_1: "DE",
                        release_dates: [
                            TMDbReleaseDate(
                                certification: "12",
                                descriptors: nil,
                                iso_639_1: nil,
                                note: nil,
                                release_date: "2016-12-15T00:00:00.000Z",
                                type: 4
                            ),
                            TMDbReleaseDate(
                                certification: "12",
                                descriptors: nil,
                                iso_639_1: nil,
                                note: nil,
                                release_date: "2016-11-24T00:00:00.000Z",
                                type: 3
                            )
                        ]
                    )
                ]
            )
        )

        let releaseText = MovieReleaseDatePresentation.preferredReleaseDateText(
            releaseDates: details.release_dates,
            regionCode: "DE",
            fallbackReleaseDate: details.release_date
        )

        #expect(releaseText == "24.11.2016")
    }

    @Test func fallbackReleaseDateIsUsedWhenRegionHasNoRelease() {
        let details = makeDetails(releaseDates: TMDbReleaseDatesResponse(results: []))

        let releaseText = MovieReleaseDatePresentation.preferredReleaseDateText(
            releaseDates: details.release_dates,
            regionCode: "DE",
            fallbackReleaseDate: details.release_date
        )

        #expect(releaseText == "10.11.2016")
    }

    @Test func missingDataDoesNotCreateEmptyFactItems() {
        let details = TMDbMovieDetails(
            id: 42,
            title: "Arrival",
            release_date: nil,
            original_title: "Arrival",
            original_language: nil,
            runtime: nil,
            vote_average: 8.4,
            release_dates: TMDbReleaseDatesResponse(results: []),
            production_companies: [],
            production_countries: [],
            status: "   ",
            budget: 0,
            revenue: 0
        )

        let presentation = MovieFactsPresentation.make(
            details: details,
            fallbackReleaseDate: nil,
            displayTitle: "Arrival",
            regionCode: "DE"
        )

        #expect(presentation == nil)
    }

    @Test func budgetAndRevenueWithZeroAreNotShown() {
        let details = makeDetails(budget: 0, revenue: 0)
        let presentation = MovieFactsPresentation.make(
            details: details,
            fallbackReleaseDate: details.release_date,
            displayTitle: "Arrival",
            regionCode: "DE"
        )

        let ids = presentation?.items.map(\.id) ?? []

        #expect(!ids.contains("budget"))
        #expect(!ids.contains("revenue"))
    }

    @Test func factsIncludeRuntimeReleaseCertificationAndProductionData() {
        let details = makeDetails()
        let presentation = MovieFactsPresentation.make(
            details: details,
            fallbackReleaseDate: details.release_date,
            displayTitle: "Die Ankunft",
            regionCode: "DE"
        )

        let valuesById = Dictionary(uniqueKeysWithValues: presentation?.items.map { ($0.id, $0.value) } ?? [])

        #expect(valuesById["runtime"] == "116 Min.")
        #expect(valuesById["releaseDate"] == "10.11.2016")
        #expect(valuesById["certification"] == "FSK 12")
        #expect(valuesById["originalLanguage"] == "Englisch")
        #expect(valuesById["originalTitle"] == "Arrival")
        #expect(valuesById["studio"] == "FilmNation Entertainment")
        #expect(valuesById["status"] == "Veröffentlicht")
        #expect(valuesById["budget"] != nil)
        #expect(valuesById["revenue"] != nil)
    }

    private func makeDetails(
        releaseDates: TMDbReleaseDatesResponse? = TMDbReleaseDatesResponse(
            results: [
                TMDbReleaseDatesCountry(
                    iso_3166_1: "DE",
                    release_dates: [
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
            ]
        ),
        budget: Int? = 47_000_000,
        revenue: Int? = 203_000_000
    ) -> TMDbMovieDetails {
        MovieMetadataTestFixtures.makeDetails(
            title: "Die Ankunft",
            originalTitle: "Arrival",
            originalLanguage: "en",
            releaseDates: releaseDates,
            budget: budget,
            revenue: revenue
        )
    }
}
