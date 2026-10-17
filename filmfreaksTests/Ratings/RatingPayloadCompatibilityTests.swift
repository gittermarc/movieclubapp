import Foundation
import Testing
@testable import filmfreaks

struct RatingPayloadCompatibilityTests {
    @Test func legacyRatingWithoutNewOptionalFieldsStillDecodes() throws {
        let payload = Data(#"{"id":"11111111-1111-1111-1111-111111111111","reviewerName":"Legacy","scores":["Action",0],"comment":"Unverändert"}"#.utf8)
        let rating = try JSONDecoder().decode(Rating.self, from: payload)

        #expect(rating.id.uuidString == "11111111-1111-1111-1111-111111111111")
        #expect(rating.reviewerId == nil)
        #expect(rating.fazitScore == nil)
        #expect(rating.updatedAt == nil)
        #expect(rating.scores == [.action: 0])
        #expect(rating.comment == "Unverändert")
        #expect(rating.averageScoreNormalizedTo10 == nil)
    }

    @Test func readingComputedValuesDoesNotChangeStoredMovieOrRatingFields() throws {
        let ratings = [
            Rating(reviewerId: UUID(), reviewerName: "Text", scores: [.emotion: 0], comment: "Text bleibt", updatedAt: Date(timeIntervalSince1970: 1_700_000_000)),
            Rating(reviewerName: "Fazit", scores: [:], comment: "Fazit bleibt", fazitScore: 7),
            Rating(reviewerName: "Kriterien", scores: [.action: 3, .music: 0])
        ]
        var movie = Movie(title: "Kompatibel", year: "2026", ratings: ratings)
        movie.groupId = "existing-group"
        movie.groupName = "Movie Club"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(movie)

        _ = movie.averageRating
        _ = movie.averageFazit
        _ = MovieRatingGroupSummary(ratings: movie.ratings)

        let after = try encoder.encode(movie)
        let decoded = try JSONDecoder().decode(Movie.self, from: after)
        #expect(before == after)
        #expect(decoded == movie)
        #expect(decoded.ratings == ratings)
        #expect(decoded.ratings.map(\.id) == ratings.map(\.id))
    }
}
