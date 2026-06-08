//
//  MovieFactsValuePresentation.swift
//  filmfreaks
//

import Foundation

enum MovieFactsValuePresentation {
    static func runtimeText(_ runtime: Int?) -> String? {
        guard let runtime, runtime > 0 else { return nil }
        return "\(runtime) Min."
    }

    static func originalLanguageText(_ languageCode: String?) -> String? {
        guard let languageCode else { return nil }
        let code = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }

        let locale = Locale(identifier: "de_DE")
        return locale.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }

    static func originalTitleText(
        _ originalTitle: String?,
        localizedTitle: String?,
        displayTitle: String
    ) -> String? {
        guard let originalTitle else { return nil }
        let trimmedOriginalTitle = originalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginalTitle.isEmpty else { return nil }

        let trimmedLocalizedTitle = localizedTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedDisplayTitle = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedLocalizedTitle.isEmpty,
           trimmedOriginalTitle.caseInsensitiveCompare(trimmedLocalizedTitle) == .orderedSame {
            return nil
        }

        if !trimmedDisplayTitle.isEmpty,
           trimmedOriginalTitle.caseInsensitiveCompare(trimmedDisplayTitle) == .orderedSame {
            return nil
        }

        return trimmedOriginalTitle
    }

    static func productionCountryText(_ countries: [TMDbProductionCountry]?) -> String? {
        guard let countries else { return nil }
        let names = countries
            .prefix(2)
            .compactMap { country -> String? in
                let code = country.iso_3166_1.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = country.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty {
                    return Locale(identifier: "de_DE").localizedString(forRegionCode: code) ?? name
                }
                return name.isEmpty ? nil : name
            }
            .filter { !$0.isEmpty }

        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    static func studioText(_ companies: [TMDbProductionCompany]?) -> String? {
        companies?
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    static func statusText(_ status: String?) -> String? {
        guard let status else { return nil }
        let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedStatus.isEmpty else { return nil }

        switch trimmedStatus.lowercased() {
        case "released":
            return "Veröffentlicht"
        case "post production":
            return "Postproduktion"
        case "in production":
            return "In Produktion"
        case "planned":
            return "Geplant"
        case "rumored":
            return "Gerücht"
        case "canceled", "cancelled":
            return "Abgebrochen"
        default:
            return trimmedStatus
        }
    }

    static func moneyText(_ value: Int?) -> String? {
        guard let value, value > 0 else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1

        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            let formatted = formatter.string(from: NSNumber(value: millions)) ?? String(format: "%.1f", millions)
            return "\(formatted) Mio. $"
        }

        let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) $"
    }
}
