//
//  MovieSearchResultsModel.swift
//  filmfreaks
//

import Foundation

struct MovieSearchResultsModel {

    private(set) var sortedResults: [TMDbMovieResult]

    init(
        results: [TMDbMovieResult] = [],
        selectedSort: MovieSearchSortOption = .relevance
    ) {
        self.sortedResults = Self.sorted(results, by: selectedSort)
    }

    mutating func update(
        results: [TMDbMovieResult],
        selectedSort: MovieSearchSortOption
    ) {
        sortedResults = Self.sorted(results, by: selectedSort)
    }

    static func sorted(
        _ results: [TMDbMovieResult],
        by selectedSort: MovieSearchSortOption
    ) -> [TMDbMovieResult] {
        switch selectedSort {
        case .relevance:
            return results

        case .titleAZ:
            return results.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        case .titleZA:
            return results.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }

        case .yearNewest:
            return results.sorted {
                (MovieSearchMapper.yearInt(from: $0.release_date) ?? -1) >
                (MovieSearchMapper.yearInt(from: $1.release_date) ?? -1)
            }

        case .yearOldest:
            return results.sorted {
                (MovieSearchMapper.yearInt(from: $0.release_date) ?? Int.max) <
                (MovieSearchMapper.yearInt(from: $1.release_date) ?? Int.max)
            }

        case .ratingHigh:
            return results.sorted { $0.vote_average > $1.vote_average }

        case .ratingLow:
            return results.sorted { $0.vote_average < $1.vote_average }
        }
    }
}
