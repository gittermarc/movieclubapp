import Foundation
import Testing
@testable import filmfreaks

struct ContentMovieItemsSnapshotBuilderTests {

    @Test func watchedListSortsByNewestWatchedDateAndPreservesStableMovieIds() {
        let olderId = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let newestId = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        let middleId = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()

        let snapshot = makeSnapshot(
            watchedMovies: [
                makeMovie(id: olderId, title: "Older", watchedDate: makeDate(year: 2024, month: 3, day: 5)),
                makeMovie(id: newestId, title: "Newest", watchedDate: makeDate(year: 2025, month: 7, day: 10)),
                makeMovie(id: middleId, title: "Middle", watchedDate: makeDate(year: 2024, month: 11, day: 1))
            ],
            sort: .dateNewest
        )

        #expect(snapshot.watchedItems.map(\.movie.title) == ["Newest", "Middle", "Older"])
        #expect(snapshot.watchedItems.map(\.movieId) == [newestId, middleId, olderId])
    }

    @Test func backlogUserFilterMatchesSuggestedByCaseInsensitively() {
        let user = User(name: "Marc")

        let snapshot = makeSnapshot(
            backlogMovies: [
                makeMovie(title: "Keep", year: "2024", suggestedBy: "mArC"),
                makeMovie(title: "Drop", year: "2025", suggestedBy: "Michi"),
                makeMovie(title: "Missing", year: "2026", suggestedBy: nil)
            ],
            filterByUser: user,
            sort: .titleAZ
        )

        #expect(snapshot.backlogItems.map(\.movie.title) == ["Keep"])
    }

    @Test func watchedUserFilterUsesReviewerIdAndLegacyReviewerNameFallback() {
        let user = User(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(), name: "Marc")

        let snapshot = makeSnapshot(
            watchedMovies: [
                makeMovie(
                    title: "By ID",
                    ratings: [makeRating(reviewerId: user.id, reviewerName: "Someone Else", average: 7)]
                ),
                makeMovie(
                    title: "By Legacy Name",
                    ratings: [makeRating(reviewerId: nil, reviewerName: "  marc  ", average: 6)]
                ),
                makeMovie(
                    title: "Filtered Out",
                    ratings: [makeRating(reviewerId: nil, reviewerName: "Michi", average: 9)]
                )
            ],
            filterByUser: user,
            sort: .titleAZ
        )

        #expect(snapshot.watchedItems.map(\.movie.title) == ["By ID", "By Legacy Name"])
    }

    @Test func searchMatchesAcrossNormalizedTokensAndSupplementalFields() {
        let snapshot = makeSnapshot(
            watchedMovies: [
                makeMovie(
                    title: "Das Leben der Anderen",
                    year: "2006",
                    watchedLocation: "Würzburg",
                    genres: ["Drama"],
                    keywords: ["Überwachung"]
                ),
                makeMovie(
                    title: "Interstellar",
                    year: "2014",
                    watchedLocation: "Berlin",
                    genres: ["Sci-Fi"],
                    keywords: ["Raumfahrt"]
                )
            ],
            watchedSearchText: "wurzburg uberwachung",
            sort: .titleAZ
        )

        #expect(snapshot.watchedItems.map(\.movie.title) == ["Das Leben der Anderen"])
    }

    @Test func ratingSortCanUseDisplayAverageIncludingTMDbFallback() {
        let snapshot = makeSnapshot(
            watchedMovies: [
                makeMovie(title: "TMDb Fallback", tmdbRating: 8.8, ratings: []),
                makeMovie(title: "Group Rating", tmdbRating: 4.0, ratings: [makeRating(reviewerId: nil, reviewerName: "Marc", average: 7)]),
                makeMovie(title: "Unrated", tmdbRating: nil, ratings: [])
            ],
            sort: .ratingHigh,
            showTMDbRatingsInLists: true
        )

        #expect(snapshot.watchedItems.map(\.movie.title) == ["TMDb Fallback", "Group Rating", "Unrated"])
    }

    @Test func emptyInputsProduceEmptySnapshot() {
        let snapshot = makeSnapshot()

        #expect(snapshot.watchedItems.isEmpty)
        #expect(snapshot.backlogItems.isEmpty)
    }

    private func makeSnapshot(
        watchedMovies: [Movie] = [],
        backlogMovies: [Movie] = [],
        watchedSearchText: String = "",
        backlogSearchText: String = "",
        filterByUser: User? = nil,
        sort: MovieSortOption = .dateNewest,
        ratingDisplayMode: RatingDisplayMode = .ratingAverage,
        showTMDbRatingsInLists: Bool = false
    ) -> ContentMovieItemsSnapshot {
        ContentMovieItemsSnapshotBuilder.build(
            input: .init(
                watchedMovies: watchedMovies,
                backlogMovies: backlogMovies,
                watchedSearchText: watchedSearchText,
                backlogSearchText: backlogSearchText,
                filterByUser: filterByUser,
                sort: sort,
                ratingDisplayMode: ratingDisplayMode,
                showTMDbRatingsInLists: showTMDbRatingsInLists
            ),
            searchIndex: MovieSearchIndexCache()
        )
    }

    private func makeMovie(
        id: UUID = UUID(),
        title: String = "Movie",
        year: String = "2024",
        tmdbRating: Double? = nil,
        ratings: [Rating] = [],
        watchedDate: Date? = nil,
        watchedLocation: String? = nil,
        suggestedBy: String? = nil,
        genres: [String]? = nil,
        keywords: [String]? = nil
    ) -> Movie {
        Movie(
            id: id,
            title: title,
            year: year,
            tmdbRating: tmdbRating,
            ratings: ratings,
            watchedDate: watchedDate,
            watchedLocation: watchedLocation,
            genres: genres,
            keywords: keywords,
            suggestedBy: suggestedBy
        )
    }

    private func makeRating(
        reviewerId: UUID?,
        reviewerName: String,
        average: Int
    ) -> Rating {
        Rating(
            reviewerId: reviewerId,
            reviewerName: reviewerName,
            scores: [.action: max(1, min(3, Int(round((Double(average) / 10.0) * 3.0))))],
            comment: nil,
            fazitScore: average,
            updatedAt: nil
        )
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
