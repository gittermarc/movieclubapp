import Foundation
import Testing
@testable import filmfreaks

struct ContentMovieSourceLookupTests {

    @Test func movieLookupUsesStableIdAfterSourceReorder() {
        let alpha = makeMovie(id: uuid("11111111-1111-1111-1111-111111111111"), title: "Alpha")
        let beta = makeMovie(id: uuid("22222222-2222-2222-2222-222222222222"), title: "Beta")
        let gamma = makeMovie(id: uuid("33333333-3333-3333-3333-333333333333"), title: "Gamma")
        let item = ContentMovieItem(movie: beta)

        let result = ContentMovieSourceLookup.movie(
            in: [gamma, alpha, beta],
            matching: item
        )

        #expect(result?.id == beta.id)
        #expect(result?.title == "Beta")
    }

    @Test func deleteConfirmationResolvesDisplayedOffsetsByStableMovieIdsAfterSourceReorder() {
        let alpha = makeMovie(id: uuid("11111111-1111-1111-1111-111111111111"), title: "Alpha")
        let beta = makeMovie(id: uuid("22222222-2222-2222-2222-222222222222"), title: "Beta")
        let gamma = makeMovie(id: uuid("33333333-3333-3333-3333-333333333333"), title: "Gamma")
        let displayedItems = [
            ContentMovieItem(movie: beta),
            ContentMovieItem(movie: gamma),
            ContentMovieItem(movie: alpha)
        ]

        let confirmation = ContentMovieSourceLookup.deleteConfirmation(
            for: IndexSet(integer: 0),
            items: displayedItems,
            movies: [gamma, alpha, beta],
            isBacklog: false
        )

        #expect(confirmation?.movieIds == [beta.id])
        #expect(confirmation?.movieTitles == ["Beta"])
        #expect(confirmation?.isBacklog == false)
    }

    @Test func deleteConfirmationIgnoresStaleItemsMissingFromSource() {
        let staleMovie = makeMovie(id: uuid("44444444-4444-4444-4444-444444444444"), title: "Gone")

        let confirmation = ContentMovieSourceLookup.deleteConfirmation(
            for: IndexSet(integer: 0),
            items: [ContentMovieItem(movie: staleMovie)],
            movies: [],
            isBacklog: true
        )

        #expect(confirmation == nil)
    }

    private func makeMovie(id: UUID, title: String) -> Movie {
        Movie(id: id, title: title, year: "2026")
    }

    private func uuid(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }
}
