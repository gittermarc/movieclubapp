import Foundation
import Testing
@testable import filmfreaks

struct MovieSearchResultsModelTests {

    @Test func relevanceKeepsOriginalTMDbOrder() {
        let results = [
            makeResult(id: 9, title: "Zulu", releaseDate: "2020-01-01", voteAverage: 5.0),
            makeResult(id: 3, title: "Alpha", releaseDate: "2024-01-01", voteAverage: 8.0),
            makeResult(id: 6, title: "Bravo", releaseDate: "2018-01-01", voteAverage: 7.0)
        ]

        let model = MovieSearchResultsModel(results: results, selectedSort: .relevance)

        #expect(model.sortedResults.map(\.id) == [9, 3, 6])
    }

    @Test func titleAZSortsCaseInsensitiveAscending() {
        let model = MovieSearchResultsModel(
            results: [
                makeResult(id: 1, title: "zebra", releaseDate: "2020-01-01", voteAverage: 7.0),
                makeResult(id: 2, title: "Alpha", releaseDate: "2019-01-01", voteAverage: 6.0),
                makeResult(id: 3, title: "mango", releaseDate: "2018-01-01", voteAverage: 5.0)
            ],
            selectedSort: .titleAZ
        )

        #expect(model.sortedResults.map(\.id) == [2, 3, 1])
    }

    @Test func titleZASortsCaseInsensitiveDescending() {
        let model = MovieSearchResultsModel(
            results: [
                makeResult(id: 1, title: "zebra", releaseDate: "2020-01-01", voteAverage: 7.0),
                makeResult(id: 2, title: "Alpha", releaseDate: "2019-01-01", voteAverage: 6.0),
                makeResult(id: 3, title: "mango", releaseDate: "2018-01-01", voteAverage: 5.0)
            ],
            selectedSort: .titleZA
        )

        #expect(model.sortedResults.map(\.id) == [1, 3, 2])
    }

    @Test func yearNewestSortsDescendingAndPlacesMissingYearsLast() {
        let model = MovieSearchResultsModel(
            results: [
                makeResult(id: 1, title: "Older", releaseDate: "1999-01-01", voteAverage: 7.0),
                makeResult(id: 2, title: "Newest", releaseDate: "2024-01-01", voteAverage: 6.0),
                makeResult(id: 3, title: "Unknown", releaseDate: nil, voteAverage: 5.0)
            ],
            selectedSort: .yearNewest
        )

        #expect(model.sortedResults.map(\.id) == [2, 1, 3])
    }

    @Test func yearOldestSortsAscendingAndPlacesMissingYearsLast() {
        let model = MovieSearchResultsModel(
            results: [
                makeResult(id: 1, title: "Older", releaseDate: "1999-01-01", voteAverage: 7.0),
                makeResult(id: 2, title: "Newest", releaseDate: "2024-01-01", voteAverage: 6.0),
                makeResult(id: 3, title: "Unknown", releaseDate: nil, voteAverage: 5.0)
            ],
            selectedSort: .yearOldest
        )

        #expect(model.sortedResults.map(\.id) == [1, 2, 3])
    }

    @Test func ratingHighSortsDescending() {
        let model = MovieSearchResultsModel(
            results: [
                makeResult(id: 1, title: "Low", releaseDate: "2020-01-01", voteAverage: 3.2),
                makeResult(id: 2, title: "High", releaseDate: "2019-01-01", voteAverage: 8.9),
                makeResult(id: 3, title: "Mid", releaseDate: "2018-01-01", voteAverage: 6.1)
            ],
            selectedSort: .ratingHigh
        )

        #expect(model.sortedResults.map(\.id) == [2, 3, 1])
    }

    @Test func ratingLowSortsAscending() {
        var model = MovieSearchResultsModel()

        model.update(
            results: [
                makeResult(id: 1, title: "Low", releaseDate: "2020-01-01", voteAverage: 3.2),
                makeResult(id: 2, title: "High", releaseDate: "2019-01-01", voteAverage: 8.9),
                makeResult(id: 3, title: "Mid", releaseDate: "2018-01-01", voteAverage: 6.1)
            ],
            selectedSort: .ratingLow
        )

        #expect(model.sortedResults.map(\.id) == [1, 3, 2])
    }

    private func makeResult(
        id: Int,
        title: String,
        releaseDate: String?,
        voteAverage: Double
    ) -> TMDbMovieResult {
        TMDbMovieResult(
            id: id,
            title: title,
            release_date: releaseDate,
            vote_average: voteAverage,
            poster_path: nil
        )
    }
}
