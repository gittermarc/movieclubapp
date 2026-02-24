//
//  SearchResultDetailView+Actions.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

extension SearchResultDetailView {

    func selectPerson(personId: Int, name: String, role: String?) {
        selectedPerson = SRSelectedPerson(id: personId, name: name, subtitle: role)
    }

    func createMovie() -> Movie {
        if let d = details {
            let year = releaseYear(from: d.release_date) ?? "n/a"

            let genreNames = d.genres?.map { $0.name }
            let genreIds = d.genres?.map { $0.id }

            let keywordNames = d.keywords?.allKeywords.map { $0.name }
            let keywordIds = d.keywords?.allKeywords.map { $0.id }

            let castMembers: [CastMember]? = d.credits?.cast
                .prefix(30)
                .map {
                    CastMember(
                        personId: $0.id,
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.name.isEmpty }

            let directorMembers: [CastMember]? = d.credits?.crew
                .filter { ($0.job ?? "").lowercased() == "director" }
                .map {
                    CastMember(
                        personId: $0.id,
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.name.isEmpty }

            return Movie(
                title: d.title,
                year: year,
                tmdbRating: d.vote_average,
                ratings: [],
                posterPath: d.poster_path,
                watchedDate: nil,
                watchedLocation: nil,
                tmdbId: d.id,
                genres: genreNames,
                genreIds: genreIds,
                keywords: keywordNames,
                keywordIds: keywordIds,
                suggestedBy: nil,
                cast: (castMembers?.isEmpty == true) ? nil : castMembers,
                directors: (directorMembers?.isEmpty == true) ? nil : directorMembers
            )
        } else {
            let year = releaseYear(from: result.release_date) ?? "n/a"
            return Movie(
                title: result.title,
                year: year,
                tmdbRating: result.vote_average,
                ratings: [],
                posterPath: result.poster_path,
                watchedDate: nil,
                watchedLocation: nil,
                tmdbId: result.id,
                genres: nil,
                genreIds: nil,
                keywords: nil,
                keywordIds: nil,
                suggestedBy: nil,
                cast: nil,
                directors: nil
            )
        }
    }
}
