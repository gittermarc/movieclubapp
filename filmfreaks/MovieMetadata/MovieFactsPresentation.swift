//
//  MovieFactsPresentation.swift
//  filmfreaks
//

import Foundation

struct MovieFactItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

struct MovieFactsPresentation: Equatable, Sendable {
    let items: [MovieFactItem]
    let certification: MovieCertificationPresentation?

    var isEmpty: Bool {
        items.isEmpty
    }

    static func make(
        details: TMDbMovieDetails,
        fallbackReleaseDate: String?,
        displayTitle: String,
        regionCode: String
    ) -> MovieFactsPresentation? {
        let certification = MovieCertificationPresentation.make(
            releaseDates: details.release_dates,
            regionCode: regionCode
        )
        var items: [MovieFactItem] = []

        appendRuntime(details.runtime, to: &items)
        appendReleaseDate(
            releaseDates: details.release_dates,
            regionCode: regionCode,
            fallbackReleaseDate: fallbackReleaseDate,
            to: &items
        )
        appendCertification(certification, to: &items)
        appendOriginalLanguage(details.original_language, to: &items)
        appendOriginalTitle(
            details.original_title,
            localizedTitle: details.title,
            displayTitle: displayTitle,
            to: &items
        )
        appendProductionCountry(details.production_countries, to: &items)
        appendStudio(details.production_companies, to: &items)
        appendStatus(details.status, to: &items)
        appendMoney(details.budget, id: "budget", title: "Budget", systemImage: "banknote", to: &items)
        appendMoney(details.revenue, id: "revenue", title: "Umsatz", systemImage: "chart.line.uptrend.xyaxis", to: &items)

        let presentation = MovieFactsPresentation(items: items, certification: certification)
        return presentation.isEmpty ? nil : presentation
    }

    private static func appendRuntime(_ runtime: Int?, to items: inout [MovieFactItem]) {
        guard let text = MovieFactsValuePresentation.runtimeText(runtime) else { return }
        items.append(
            MovieFactItem(
                id: "runtime",
                title: "Laufzeit",
                value: text,
                systemImage: "clock"
            )
        )
    }

    private static func appendReleaseDate(
        releaseDates: TMDbReleaseDatesResponse?,
        regionCode: String,
        fallbackReleaseDate: String?,
        to items: inout [MovieFactItem]
    ) {
        guard let text = MovieReleaseDatePresentation.preferredReleaseDateText(
            releaseDates: releaseDates,
            regionCode: regionCode,
            fallbackReleaseDate: fallbackReleaseDate
        ) else { return }

        items.append(
            MovieFactItem(
                id: "releaseDate",
                title: "Release",
                value: text,
                systemImage: "calendar"
            )
        )
    }

    private static func appendCertification(
        _ certification: MovieCertificationPresentation?,
        to items: inout [MovieFactItem]
    ) {
        guard let certification else { return }
        items.append(
            MovieFactItem(
                id: "certification",
                title: "Freigabe",
                value: certification.text,
                systemImage: "checkmark.seal"
            )
        )
    }

    private static func appendOriginalLanguage(_ languageCode: String?, to items: inout [MovieFactItem]) {
        guard let text = MovieFactsValuePresentation.originalLanguageText(languageCode) else { return }
        items.append(
            MovieFactItem(
                id: "originalLanguage",
                title: "Originalsprache",
                value: text,
                systemImage: "globe.europe.africa"
            )
        )
    }

    private static func appendOriginalTitle(
        _ originalTitle: String?,
        localizedTitle: String?,
        displayTitle: String,
        to items: inout [MovieFactItem]
    ) {
        guard let text = MovieFactsValuePresentation.originalTitleText(
            originalTitle,
            localizedTitle: localizedTitle,
            displayTitle: displayTitle
        ) else { return }

        items.append(
            MovieFactItem(
                id: "originalTitle",
                title: "Originaltitel",
                value: text,
                systemImage: "text.quote"
            )
        )
    }

    private static func appendProductionCountry(
        _ countries: [TMDbProductionCountry]?,
        to items: inout [MovieFactItem]
    ) {
        guard let text = MovieFactsValuePresentation.productionCountryText(countries) else { return }
        items.append(
            MovieFactItem(
                id: "productionCountry",
                title: "Produktionsland",
                value: text,
                systemImage: "map"
            )
        )
    }

    private static func appendStudio(_ companies: [TMDbProductionCompany]?, to items: inout [MovieFactItem]) {
        guard let text = MovieFactsValuePresentation.studioText(companies) else { return }
        items.append(
            MovieFactItem(
                id: "studio",
                title: "Studio",
                value: text,
                systemImage: "building.2"
            )
        )
    }

    private static func appendStatus(_ status: String?, to items: inout [MovieFactItem]) {
        guard let text = MovieFactsValuePresentation.statusText(status) else { return }
        items.append(
            MovieFactItem(
                id: "status",
                title: "Status",
                value: text,
                systemImage: "flag"
            )
        )
    }

    private static func appendMoney(
        _ value: Int?,
        id: String,
        title: String,
        systemImage: String,
        to items: inout [MovieFactItem]
    ) {
        guard let text = MovieFactsValuePresentation.moneyText(value) else { return }
        items.append(
            MovieFactItem(
                id: id,
                title: title,
                value: text,
                systemImage: systemImage
            )
        )
    }
}
